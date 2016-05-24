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

use Code::Tooling::Perl;
use Parallel::ForkManager;

use Importer 'Code::Tooling::Util::JSON'       => qw[ encode decode ];
use Importer 'Code::Tooling::Util::FileSystem' => qw[ traverse_filesystem ];

our $DEBUG = 0;
our $ROOT;

sub main {

    my ($exclude, $include, $parallel_processors_cnt);
    Getopt::Long::GetOptions(
        'root=s'                => \$ROOT,
        # filters
        'exclude=s'             => \$exclude,
        'include=s'             => \$include,
        # development
        'verbose'               => \$DEBUG,
        'parallel_process=i'    => \$parallel_processors_cnt,
    );

    (-e $ROOT && -d $ROOT)
        || die 'You must specifiy a valid root directory';

    $ROOT = Path::Class::Dir->new( $ROOT );

    (defined $include && defined $exclude)
        && die 'You can not have both include and exclude patterns';

    (defined $parallel_processors_cnt && ($parallel_processors_cnt<=0 || $parallel_processors_cnt>10))
        && die 'parallel_process has to be in the range [1,10]';

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
    extract_critique_info_serially( \@files, \@critiques ) if(!$parallel_processors_cnt);
    extract_critique_info_parallely( \@files, \@critiques, $parallel_processors_cnt ) if($parallel_processors_cnt);

    # Step 3. - Prepare (machine readable) report of status of critiques
    print encode( \@critiques );
}

main && exit;

sub extract_file_names ($source, $files) {
    push @$files , $source if $source->stringify =~ /\.p[ml]$/ ;
    return;
}

sub extract_critique_info_serially ($files, $critiques) {
    my $perl = Code::Tooling::Perl->new;
    for my $file ( @$files ) {
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
    return; 
}

sub extract_critique_info_parallely ($files, $merged_critiques, $parallel_processors_cnt) {
    my $pm = Parallel::ForkManager->new($parallel_processors_cnt);

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
    my $seg_size = int( (@$files) / $parallel_processors_cnt ) + int( ( (@$files) % $parallel_processors_cnt ) ? 1 : 0);

    #divide in groups to be processed by each process
    my @files_groups;
    push @files_groups, [ splice @$files, 0, $seg_size ] while @$files;

    my $id = 1;
    my @temp_file_handlers;
    for my $cur_files ( @files_groups ) {
        my $output_file = File::Temp->new();
        push @temp_file_handlers, $output_file;
        my $pid = $pm->start('child_'.$id); # do the fork
        if ($pid == 0) {
            my @critiques;
            extract_critique_info_serially( $cur_files, \@critiques );
            $output_file->write( encode( \@critiques ) );
            $pm->finish;
        }
        $id++;
    }
    $pm->wait_all_children;

    for my $temp_fh ( @temp_file_handlers ) {
        $temp_fh->seek(0, 0);
        my $content = join '' => <$temp_fh>;
        my $critiques = decode($content);
        push $merged_critiques->@*, $critiques->@*;
    }
    return;
}


1;
