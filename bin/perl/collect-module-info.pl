#!perl

use v5.22;
use warnings;

use lib 'lib';

use experimental qw[
    signatures
    postderef
];

use Path::Class  ();
use Getopt::Long ();
use Data::Dumper ();

use Code::Tooling::Git;
use Code::Tooling::Perl;

use Importer 'Code::Tooling::Util::JSON'       => qw[ encode decode ];
use Importer 'Code::Tooling::Util::FileSystem' => qw[ traverse_filesystem ];

our $DEBUG = 0;

sub main {

    my ($checkout, $offline);
    Getopt::Long::GetOptions(
        'checkout=s' => \$checkout,
        'offline'    => \$offline,
        'verbose'    => \$DEBUG,
    );

    (-e $checkout && -d $checkout)
        || die 'You must specifiy a valid checkout directory';

    $checkout = Path::Class::Dir->new( $checkout );

    my $perl = Code::Tooling::Perl->new;
    my $git  = Code::Tooling::Git->new( work_tree => $checkout );

    my $input = join '' => <STDIN>;
    my $data  = decode( $input );

    (ref $data eq 'ARRAY')
        || die "Can only collate JSON arrays, not:\n$input";

    # The input data structure (@modules) is
    # as follows:
    # {
    #     namespace : String,    # name of the package
    #     line_num  : Int,       # line number package began at
    #     path      : Str,       # path of the file package was in
    #     version   : VString    # value of $VERSION
    # }
    # and we add the `rel_path` to it to make
    # it relevant to the checkout

    my @modules = map {
        $_->{rel_path} = Path::Class::Dir->new( $_->{path} )->relative( $checkout )->stringify;
        $_;
    } @$data;

    # Step 2. - check if the file has been modified
    #           locally by git log
    check_file_changes_locally( $git, \@modules );

    if ( not $offline ) {
        # Step 3. - Query MetaCPAN to find the module and see how
        #           much our version number differs.
        check_module_versions_against_metacpan( $perl, \@modules );

        # Step 4. - Query MetaCPAN to get the module's source and
        #           see how much it differs from our source
        check_file_changes_remotely( $perl, $checkout, \@modules );

        # Step 5. - Query MetaCPAN to get the module author's information,
        #           source repository and bug tracker information
        find_authors_information( $perl, \@modules );
    }

    # Step 6. - Prepare (machine readable) report of status of modules
    print encode( \@modules );
}

main && exit;

# subs ....
sub find_authors_information ($perl, $modules) {

    foreach my $module ( $modules->@* ) {
        #check if this file has been modified in remote repo
        warn "Going to compared files about $module->{namespace}" if $DEBUG;
        if($module->{cpan} && $module->{cpan}->{author}) {
            warn "Going to fetch authors data about $module->{namespace}" if $DEBUG;
            eval {
                my $author = $perl->metacpan->get_author_info($module->{cpan}->{author});
                $module->{cpan}->{authors_info} = {
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

sub check_file_changes_remotely ($perl, $checkout, $modules) {

    foreach my $module ( $modules->@* ) {
        #check if this file has been modified in remote repo
        warn "Going to compared files about $module->{namespace}" if $DEBUG;
        if ($module->{cpan} && $module->{cpan}->{author}  && $module->{cpan}->{release}) {
            warn "Going to fetch data about $module->{namespace}" if $DEBUG;
            eval {
                my $source = $perl->metacpan->get_file_source(
                    $module->{cpan}->{author},
                    $module->{cpan}->{release},
                    $module->{rel_path}
                );
                my $file = Path::Class::File->new( $module->{path} );
                my $local = $file->slurp;
                my $remote = $source;
                $module->{modules_differ} = $remote eq $local ? 1:0;
                warn "Succesfully compared files about $module->{namespace}" if $DEBUG;
                1;
            } or do {
                warn "Unable to compared files about $module->{namespace} because $@" if $DEBUG;
            };
        }
    }
}

sub check_file_changes_locally ($git, $modules) {

    foreach my $module ( $modules->@* ) {
        #check if this file has been modified in local repo
        warn "Going to check git log about $module->{namespace}" if $DEBUG;
        eval {
            my $logs = $git->log( $module->{path}, { debug => $DEBUG } );
            my $author_commits = {};
            for my $log( @$logs ) {
                $author_commits->{  $log->{author}->{name} } //= [];
                push $author_commits->{ $log->{author}->{name} }->@*,$log->{sha};
            }
            $module->{local_changes}->{first}   = $logs->[0] if @$logs;
            $module->{local_changes}->{last}    = $logs->[-1] if @$logs;
            $module->{local_changes}->{authors} = $author_commits;
            warn "Succesfully checked git log about $module->{namespace}" if $DEBUG;
            1;
        } or do {
            warn "Unable to check git log about $module->{namespace} because $@" if $DEBUG;
        };
    }
}

sub check_module_versions_against_metacpan ($perl, $modules) {

    foreach my $module ( $modules->@* ) {
        warn "Going to fetch data about $module->{namespace}" if $DEBUG;
        eval {
            my $meta_data = $perl->metacpan->get_module_info(
                $module->{namespace} => (
                    fields => join ',' => qw[
                        version
                        version_numified
                        author
                        date
                        release
                        distribution
                    ]
                )
            );
            $module->{cpan} = $meta_data->{data} // {};
            warn "Succesfully fetch data about $module->{namespace}" if $DEBUG;
            1;
        } or do {
            warn "Unable to fetch data about $module->{namespace} because $@" if $DEBUG;
        };
    }
}

1;
