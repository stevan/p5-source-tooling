#!perl

use strict;
use warnings;

use lib 'lib';

use Path::Class  ();
use Getopt::Long ();
use Data::Dumper ();

use PPI;
use MetaCPAN::Client;

use Code::Tooling::Util::JSON qw[ encode ];

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


    if ( not $offline ) {
        # Step 2. - Query MetaCPAN to find the module and see how
        #           much our version number differs.

        my $mcpan = MetaCPAN::Client->new;

        check_module_versions_against_metacpan(
            $mcpan, (
                modules => \@modules
            )
        );

        # Step 3. - Query MetaCPAN to get the module's source and
        #           see how much it differs from our source

        # Step 4. - Query MetaCPAN to get the module author's information,
        #           source repository and bug tracker information
    }

    # Step 5. - Prepare (machine readable) report of status of modules

    print encode( \@modules );
}

main && exit;

# subs ....

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
                meta      => {},
            };

            push @$modules => $current;

            warn "Found package '$current->{namespace}' in '$e'" if $DEBUG;
        }

        return;
    });
}

1;
