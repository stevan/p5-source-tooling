#!perl

use strict;
use warnings;

use lib 'lib';

use experimental qw[
    state
    signatures
    postderef
];

use Path::Class  ();
use Getopt::Long ();
use Data::Dumper ();

use PPI;
use MetaCPAN::Client;
use Code::Tooling::Git;
use Code::Tooling::Util::JSON qw[ encode ];
use Code::Tooling::Perl;

use Importer 'Code::Tooling::Util::JSON'       => qw[ encode ];
use Importer 'Code::Tooling::Util::FileSystem' => qw[ traverse_filesystem ];

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
        $ROOT,
        \&extract_module_info,
        \@modules,
        (
            ($exclude ? (exclude => $exclude) : ()),
            ($include ? (include => $include) : ()),
        )
    );

    # Step 2. - check if the file has been modified
    #           locally by git log
    check_file_changes_locally(
       $ROOT, (
           modules => \@modules
       )
    );

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
            $mcpan, $ROOT, (
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
    print encode( \@modules );
}

main && exit;

# subs ....
sub find_authors_information ($mcpan, %args) {

    foreach my $module ( $args{modules}->@* ) {
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
                warn "Unable to fetch authors data about $module->{namespace} because $@" if $DEBUG;
            };
        }
    }
}

sub check_file_changes_remotely ($mcpan, $checkout, %args) {

    foreach my $module ( $args{modules}->@* ) {
        #check if this file has been modified in remote repo
        warn "Going to compared files about $module->{namespace}" if $DEBUG;
        if($module->{meta}->{cpan}->{author} &&
           $module->{meta}->{cpan}->{release} &&
           $module->{rel_path}) {
            warn "Going to fetch data about $module->{namespace}" if $DEBUG;
            eval {
                my $remote_file_path = 'https://api.metacpan.org/source/'.$module->{meta}->{cpan}->{author}.
                                       '/'.$module->{meta}->{cpan}->{release}.
                                       '/'.$module->{rel_path};
                my $cpan_module = $mcpan->ua->get( $remote_file_path );
                my $file = Path::Class::File->new( $module->{path} );
                my $local = $file->slurp;
                my $remote = $cpan_module->{content};
                $module->{modules_differ} = $remote eq $local ? 1:0;
                warn "Succesfully compared files about $module->{namespace}" if $DEBUG;
                1;
            } or do {
                warn "Unable to compared files about $module->{namespace} because $@" if $DEBUG;
            };
        }
    }
}

sub check_file_changes_locally ($checkout, %args) {

    foreach my $module ( $args{modules}->@* ) {
        #check if this file has been modified in local repo
        warn "Going to check git log about $module->{namespace}" if $DEBUG;
        eval {
            my $logs = Code::Tooling::Git->new(
                work_tree => $checkout
            )->log(
                $module->{path},
                {
                    debug => $DEBUG,
                }
            );
            my $author_commits = {};
            for my $log( @$logs ) {
                $author_commits->{  $log->{author}->{name} } //= [];
                push $author_commits->{ $log->{author}->{name} }->@*,$log->{sha};
            }
            $module->{first_local_change} = $logs->[0] if @$logs;
            $module->{last_local_change} = $logs->[-1] if @$logs;
            $module->{authors_changing_locally} = $author_commits;
            warn "Succesfully checked git log about $module->{namespace}" if $DEBUG;
            1;
        } or do {
            warn "Unable to check git log about $module->{namespace} because $@" if $DEBUG;
        };
    }
}

sub check_module_versions_against_metacpan ($mcpan, %args) {

    foreach my $module ( $args{modules}->@* ) {
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

sub extract_module_info ($source, $acc) {
    state $perl = Code::Tooling::Perl->new;

    push @$acc => map {
        $_->{rel_path} = Path::Class::Dir
            ->new( $_->{path} )
            ->relative( $ROOT )
            ->stringify;
        $_;
    } $perl->extract_module_info( $source )->@*;
    return;
}

1;
