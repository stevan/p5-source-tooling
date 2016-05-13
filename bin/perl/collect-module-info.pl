#!perl

use strict;
use warnings;

use lib 'lib';

use Path::Class  ();
use Getopt::Long ();
use Data::Dumper ();

use JSON::XS qw(encode_json decode_json);

use PPI;
use MetaCPAN::Client;
use Code::Tooling::Git;
use Code::Tooling::Util::JSON qw[ encode ];

use Text::Diff;
use Path::Tiny;
use File::Slurp qw(read_file write_file);

our $DEBUG = 0;
our $ROOT;

sub main {

    my ($exclude, $include, $offline);
    Getopt::Long::GetOptions(
        'root=s'    => \$ROOT,
        # filters
        'exclude=s' => \$exclude,
        'include=s' => \$include,
        # development
        'offline'   => \$offline,
        'verbose'   => \$DEBUG,
    );

    (-e $ROOT && -d $ROOT)
        || die 'You must specifiy a valid root directory';

    $ROOT = Path::Class::Dir->new( $ROOT );

    (defined $include && defined $exclude)
        && die 'You can not have both include and exclude patterns';

    my @modules;

    # The data structure within @modules is
    # as follows:
    # {
    #     namespace : String,    # name of the package
    #     line_num  : Int,       # line number package began at
    #     path      : Str,       # path of the file package was in
    #     meta      : {          # ... module meta-data
    #         version : VString  # value of $VERSION
    #         cpan    : HashRef  # data from MetaCPAN
    #     }
    # }

    # Step 1. - Traverse the file system and collect info about
    #           modules and their version numbers

    traverse_filesystem(
        $ROOT, (
            ($exclude ? (exclude => $exclude) : ()),
            ($include ? (include => $include) : ()),
            visitor => \&extract_module_version_information,
            modules => \@modules,
        )
    );
    print "traversed";

    # Step 2. - check if the file has been modified
    #           locally by git log
    #check_file_changes_locally(
    #   $ROOT, (
    #       modules => \@modules
    #   )
    #);

    if ( not $offline ) {
        # Step 3. - Query MetaCPAN to find the module and see how
        #           much our version number differs.

        my $mcpan = MetaCPAN::Client->new;

        check_module_versions_against_metacpan(
            $mcpan, (
                modules => \@modules
            )
        );

        # Step 4. - Query MetaCPAN to get the module's source and
        #           see how much it differs from our source
        check_file_changes_remotely(
            $mcpan,$ROOT, (
                modules => \@modules
            )
        );

        # Step 5. - Query MetaCPAN to get the module author's information,
        #           source repository and bug tracker information
        find_authors_information(
            $mcpan, (
                modules => \@modules
            )
        );
    }

    # Step 6. - Prepare (machine readable) report of status of modules
    my $json = encode_json \@modules;
    write_file('report.json', { binmode => ':raw' }, $json);

    print encode( \@modules );
}

main && exit;



# subs ....
sub find_authors_information {
    my ($mcpan, %args) = @_;

    foreach my $module ( @{ $args{modules} } ) {
        #check if this file has been modified in remote repo
        warn "Going to compared files about $module->{namespace}" if $DEBUG;
        if($module->{meta}->{cpan}->{author}) {
            warn "Going to fetch authors data about $module->{namespace}" if $DEBUG;
            eval {
                my $author = $mcpan->author($module->{meta}->{cpan}->{author});
                $module->{meta}->{cpan}->{authors_info} = {
                    name        => $author->name,
                    website     => $author->website,
                    blog        => $author->blog,
                    profile     => $author->profile,
                    website     => $author->website,  
                };
                warn "Succesfully fetched authors data about $module->{namespace}" if $DEBUG;
                1;
            } or do {
                warn "Unable to fetch authors data about $module->{namespace} because $@";
            };
        }
    }
}

sub check_file_changes_remotely {
    my ($mcpan, $checkout, %args) = @_;

    foreach my $module ( @{ $args{modules} } ) {
        #check if this file has been modified in remote repo
        warn "Going to compared files about $module->{namespace}" if $DEBUG;
        if($module->{meta}->{cpan}->{author} &&
           $module->{meta}->{cpan}->{release} &&
           $module->{rel_path}) {
            warn "Going to fetch data about $module->{namespace}" if $DEBUG;
            eval {
                my $remote_file_path = 'https://api.metacpan.org/source/{author}/{release}/{path-to-file}';
                $remote_file_path=~s/{author}/$module->{meta}->{cpan}->{author}/g;
                $remote_file_path=~s/{release}/$module->{meta}->{cpan}->{release}/g;
                $remote_file_path=~s/{path-to-file}/$module->{rel_path}/g;
                my $cpan_module = $mcpan->ua->get( $remote_file_path );
                my $file = path($module->{path});
                my $local = $file->slurp;
                my $remote = $cpan_module->{content};
                $module->{modules_differ} = $remote eq $local ? 1:0;
                warn "Succesfully compared files about $module->{namespace}" if $DEBUG;
                1;
            } or do {
                warn "Unable to compared files about $module->{namespace} because $@";
            };
        }
    }
}

sub check_file_changes_locally {
    my ($checkout, %args) = @_;

    foreach my $module ( @{ $args{modules} } ) {
        #check if this file has been modified in local repo
        warn "Going to check git log about $module->{namespace}" if $DEBUG;
        eval {
            my $logs = Code::Tooling::Git->new(
                work_tree => $checkout
            )->log(
                $module->{rel_path},
                {
                    debug     => $DEBUG,
                }
            );
            my $author_commits = {};
            for my $log( @$logs ) {
                $author_commits->{  $log->{author}->{name} } //= [];
                push $author_commits->{ $log->{author}->{name} },$log->{sha};
            }
            $module->{authors_changing_locally} = $author_commits;
            warn "Succesfully checked git log about $module->{namespace}";
            1;
        } or do {
            warn "Unable to check git log about $module->{namespace} because $@";
        };
    }
}

sub check_module_versions_against_metacpan {
    my ($mcpan, %args) = @_;

    foreach my $module ( @{ $args{modules} } ) {
        warn "Going to fetch data about $module->{namespace}" if $DEBUG;
        eval {
            my $meta_data = $mcpan->module(
                $module->{namespace}, {
                    fields => join ',' => qw[
                        version
                        version_numified
                        author
                        date
                        release
                        distribution
                    ]
                }
            );
            $module->{meta}->{cpan} = $meta_data->{data};
            warn "Succesfully fetch data about $module->{namespace}" if $DEBUG;
            1;
        } or do {
            warn "Unable to fetch data about $module->{namespace} because $@" if $DEBUG;
        };
    }
}

sub traverse_filesystem {
    my ($e, %args) = @_;

    if ( -f $e ) {
        $args{visitor}->( $e, $args{modules} )
            if $e->basename =~ /\.p[ml]/i;
    }
    else {
        warn "Got e($e) and ROOT($ROOT)" if $DEBUG;

        my @children = $e->children( no_hidden => 1 );
        warn "ROOT: GOT children: " . Data::Dumper::Dumper([ map $_->relative( $ROOT )->stringify, @children ]) if $DEBUG;

        if ( my $exclude = $args{exclude} ) {
            warn "ROOT: Looking to exclude '$exclude' ... got: " . $e->basename if $DEBUG;
            @children = grep $_->relative( $ROOT )->stringify !~ /$exclude/, @children;
        }

        if ( my $include = $args{include} ) {
            warn "ROOT: Looking to include '$include' ... got: " . $e->basename if $DEBUG;
            @children = grep $_->relative( $ROOT )->stringify =~ /$include/, @children;
        }

        warn "ROOT: Getting ready to run with children: " . Data::Dumper::Dumper([ map $_->relative( $ROOT )->stringify, @children ]) if $DEBUG;
        map traverse_filesystem( $_, %args ), @children;
    }

    return;
}

sub extract_module_version_information {
    my ($e, $modules) = @_;

    warn "Looking at '$e'" if $DEBUG;

    my $doc = PPI::Document->new( $e->stringify );

    (defined $doc)
        || die 'Could not load document: ' . $e->stringify;

    my $current;
    $doc->find(sub {
        my ($root, $node) = @_;

        # if we have a current namespace, descend to find version ...
        if ( $current ) {

            # Must be a quote or number
            $node->isa('PPI::Token::Quote')          or
            $node->isa('PPI::Token::Number')         or return '';

            # To the right is a statement terminator or nothing
            my $t = $node->snext_sibling;
            if ( $t ) {
                $t->isa('PPI::Token::Structure') or return '';
                $t->content eq ';'               or return '';
            }

            # To the left is an equals sign
            my $eq = $node->sprevious_sibling        or return '';
            $eq->isa('PPI::Token::Operator')         or return '';
            $eq->content eq '='                      or return '';

            # To the left is a $VERSION symbol
            my $v = $eq->sprevious_sibling           or return '';
            $v->isa('PPI::Token::Symbol')            or return '';
            $v->content =~ m/^\$(?:\w+::)*VERSION$/  or return '';

            # To the left is either nothing or "our"
            my $o = $v->sprevious_sibling;
            if ( $o ) {
                $o->content eq 'our'             or return '';
                $o->sprevious_sibling           and return '';
            }

            warn "Found possible version in '$current->{namespace}' in '$e'" if $DEBUG;

            my $version;
            if ( $node->isa('PPI::Token::Quote') ) {
                if ( $node->can('literal') ) {
                    $version = $node->literal;
                } else {
                    $version = $node->string;
                }
            } elsif ( $node->isa('PPI::Token::Number') ) {
                if ( $node->can('literal') ) {
                    $version = $node->literal;
                } else {
                    $version = $node->content;
                }
            } else {
                die 'Unsupported object ' . ref($node);
            }

            warn "Found version '$version' in '$current->{namespace}' in '$e'" if $DEBUG;

            # we've found it!!!!
            $modules->[-1]->{meta}->{version} = $version;

            undef $current;
        }
        else {
            # otherwise wait for next package ...
            return 0 unless $node->isa('PPI::Statement::Package');
            $current = {
                namespace => $node->namespace,
                line_num  => $node->line_number,
                path      => $e->stringify,
                rel_path  => $e->relative( $ROOT->parent )->stringify,
                meta      => {},
            };

            push @$modules => $current;

            warn "Found package '$current->{namespace}' in '$e'" if $DEBUG;
        }

        return;
    });
}

1;
