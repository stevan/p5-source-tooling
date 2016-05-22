#!perl

use strict;
use warnings;

use lib 'lib';

use experimental qw[
    state
    signatures
];

use Path::Class  ();
use Getopt::Long ();
use Data::Dumper ();
use Path::Tiny;

use Code::Tooling::Perl;
use Parallel::ForkManager;

use Importer 'Code::Tooling::Util::JSON'       => qw[ encode ];
use Importer 'Code::Tooling::Util::FileSystem' => qw[ traverse_filesystem ];

our $DEBUG = 0;
our $ROOT;
our $MAX_PROCESS_CNT;

sub main {

    my ($exclude, $include);
    Getopt::Long::GetOptions(
        'root=s'            => \$ROOT,
        # filters
        'exclude=s'         => \$exclude,
        'include=s'         => \$include,
        # development
        'verbose'           => \$DEBUG,
        'parallel_process'  => \$MAX_PROCESS_CNT,
    );

    (-e $ROOT && -d $ROOT)
        || die 'You must specifiy a valid root directory';

    $ROOT = Path::Class::Dir->new( $ROOT );

    (defined $include && defined $exclude)
        && die 'You can not have both include and exclude patterns';

    (defined ($MAX_PROCESS_CNT) && $MAX_PROCESS_CNT !~ /^\d+\$/)
        && die 'parallel_process has to be a number';

    my @files;

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
    extract_critique_info_serially( \@files ) if(!$MAX_PROCESS_CNT);
    extract_critique_info_parallely( \@files ) if($MAX_PROCESS_CNT);
}

main && exit;

sub extract_critique_info_serially ($files) {
    my $perl = Code::Tooling::Perl->new;
    my $output_file = path( 'serial.out' );
    for my $file ( @$files ) {
        eval {
            my $critique_hash = {};
            $critique_hash->{critique} = $perl->critique( $file,{} );
            $critique_hash->{file_name} = $file->stringify;
            warn "Succesfully fetched critique info about $file" if $DEBUG;
            $output_file->append(encode($critique_hash));
            1;
        } or do {
            warn "Unable to fetch critique info about $file because $@" if $DEBUG;
        };
    }
}

sub extract_file_names ($source, $files) {
    push @$files , $source if $source->stringify =~ /.*\.p[ml]$/ ;
    return;
}

sub extract_critique_info_parallely ($files) {
    my $perl = Code::Tooling::Perl->new;
    my $pm = Parallel::ForkManager->new($MAX_PROCESS_CNT);

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
    my $seg_size = $MAX_PROCESS_CNT>0 ? (((@$files)/$MAX_PROCESS_CNT)+ 1 ) : 1;

    #randomizing the files to get a better distribution
    #@$files = rand @$files;

    #divide in groups to be processed by each process
    my @files_groups;
    push @files_groups, [ splice @$files, 0, $seg_size ] while @$files;

    my $id = 1;
    for my $cur_files ( @files_groups ) {
        my $pid = $pm->start('child_'.$id); # do the fork
        if ($pid == 0) {
            my $output_file = path( $id.'.out' );
            for my $file ( @$cur_files ) {
                eval {
                    my $critique_hash = {};
                    $critique_hash->{critique} = $perl->critique( $file,{} );
                    $critique_hash->{file_name} = $file->stringify;
                    warn "Succesfully fetched critique info about $file" if $DEBUG;
                    $output_file->append(encode($critique_hash));
                    1;
                } or do {
                    warn "Unable to fetch critique info about $file because $@" if $DEBUG;
                };
            }
            #print encode($cur_critiques);
            $pm->finish;
        }
        $id++;
    }
    $pm->wait_all_children;
    return;
}


1;
