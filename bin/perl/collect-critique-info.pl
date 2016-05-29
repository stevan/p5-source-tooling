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

use Code::Tooling::Perl;
use Parallel::ForkManager;

use Importer 'Code::Tooling::Util::JSON'       => qw[ encode decode ];
use Importer 'Code::Tooling::Util::FileSystem' => qw[ traverse_filesystem ];
use Importer 'Code::Tooling::Util::Transform'  => qw[ split_array_equally ];

our $DEBUG = 0;
our $ROOT;

sub main {

    my ($exclude, $include, $num_processes);
    Getopt::Long::GetOptions(
        'root=s'                => \$ROOT,
        # filters
        'exclude=s'             => \$exclude,
        'include=s'             => \$include,
        # development
        'verbose'               => \$DEBUG,
        'num_processes=i'       => \$num_processes,
    );

    (-e $ROOT && -d $ROOT)
        || die 'You must specifiy a valid root directory';

    $ROOT = Path::Class::Dir->new( $ROOT );

    (defined $include && defined $exclude)
        && die 'You can not have both include and exclude patterns';

    (defined $num_processes && ($num_processes<1 || $num_processes>50))
        && die 'num_processes has to be in the range [1,10]';

    my (@files, @critiques);

    # The data structure within @critiques is
    # as follows:
    #  {
    #    statistics : {
    #       lines   : {
    #          blank    : Int,
    #          comments : Int,
    #          data     : Int,
    #          perl     : Int,
    #          pod      : Int,
    #          total    : Int
    #       },
    #       modules     : Int,
    #       statements  : Int,
    #       subs        : Int,
    #       violations  : {
    #          total        : Int
    #       }
    #    },
    #    violations : [
    #       {
    #          description  : Str,
    #          policy       : Str,
    #          severity     : Int,
    #          source       : {
    #               code : Str,
    #               location : {
    #                   column  : Int,
    #                   line    : Int,
    #               }
    #          }
    #       }
    #    ]
    #  }

    # Step 1. - Traverse the file system and collect info about
    #           perl critiques
    traverse_filesystem(
        $ROOT,
        \&extract_file_names,
        \@files,
        (
            ($exclude ? (exclude => $exclude) : ()),
            ($include ? (include => $include) : ()),
        )
    );

    # Step 2. - generate critique info serially/paralelly
    if($num_processes) {
        extract_critique_info_parallely( \@files, \@critiques, $num_processes );
    } else {
        extract_critique_info_serially( \@files, \@critiques );
    }

    # Step 3. - Prepare (machine readable) report of status of critiques
    print encode( \@critiques );
}

main && exit;

sub extract_file_names ($source, $files) {
    push @$files , $source if $source->stringify =~ /\.p[ml]$/ ;
    return;
}

sub extract_critique_info_serially ($files, $critiques) {
    my $perl = Code::Tooling::Perl->new(
        perlcritic_profile => $ENV{CRITIC_PROFILE},
        perl_version       => $ENV{PERL_VERSION},
    );
    for my $file ( $files->@* ) {
        eval {
            my $critique_hash = {};
            $critique_hash->{critique} = $perl->critique( $file,{} );
            $critique_hash->{file_name} = $file->stringify;
            warn "Succesfully fetched critique info about $file" if $DEBUG;
            push $critiques->@*, $critique_hash;
            1;
        } or do {
            warn "Unable to fetch critique info about $file because $@" if $DEBUG;
        };
    }
}

sub extract_critique_info_parallely ($files, $merged_critiques, $num_processes) {
    my $pm = Parallel::ForkManager->new($num_processes);

    $pm->run_on_finish( sub {
        my ($pid, $exit_code, $ident) = @_;
        print "** $ident just got out of the pool ".
        "with PID $pid and exit code: $exit_code\n" if $DEBUG;
    });

    $pm->run_on_start( sub {
        my ($pid, $ident)=@_;
        print "** $ident started, pid: $pid\n" if $DEBUG;
    });

    $pm->run_on_wait( sub {
            print "** waiting for children ...\n" if $DEBUG;
        },
        60
    );

    # divide files in groups to be processed by each process
    my $files_groups = split_array_equally($files, $num_processes);

    # run all the process parallely to generate result
    my $temp_dir = Path::Class::tempdir(CLEANUP => 1);
    for my $cur_files ( $files_groups->@* ) {
        my ($temp_output_file,$name) = $temp_dir->tempfile();
        my $pid = $pm->start(); # do the fork
        if ($pid == 0) {
            my @critiques;
            extract_critique_info_serially( $cur_files, \@critiques );
            $temp_output_file->write( encode( \@critiques ) );
            $pm->finish;
        }
    }
    $pm->wait_all_children;

    # merge all the temp files inside the temp dir
    for my $temp_fh ( $temp_dir->children() ) {
        my $content = $temp_fh->slurp;
        my $critiques = decode($content);
        push $merged_critiques->@*, $critiques->@*;
    }
    warn "parallel run was successful" if $DEBUG;
}

1;
