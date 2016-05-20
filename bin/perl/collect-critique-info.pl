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

use Code::Tooling::Perl;
use Parallel::ForkManager;

use Importer 'Code::Tooling::Util::JSON'       => qw[ encode ];
use Importer 'Code::Tooling::Util::FileSystem' => qw[ traverse_filesystem ];

our $DEBUG = 0;
our $ROOT;
our $MAX_PROCESS_CNT = 3;
our $PCS_CNT = 0;

sub main {

    my ($exclude, $include, $offline);
    Getopt::Long::GetOptions(
        'root=s'    => \$ROOT,
        # filters
        'exclude=s' => \$exclude,
        'include=s' => \$include,
        # development
        'verbose'   => \$DEBUG,
    );

    (-e $ROOT && -d $ROOT)
        || die 'You must specifiy a valid root directory';

    $ROOT = Path::Class::Dir->new( $ROOT );

    (defined $include && defined $exclude)
        && die 'You can not have both include and exclude patterns';

    my @critiques;

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
        \@critiques,
        (
            ($exclude ? (exclude => $exclude) : ()),
            ($include ? (include => $include) : ()),
        )
    );

    # Step 2. - generate critique info serially/paralelly
    #extract_critique_info_parallely( \@critiques );
    extract_critique_info_serially( \@critiques );
}

main && exit;

sub extract_critique_info_serially ($critiques) {
    my $perl = Code::Tooling::Perl->new;
    for my $critique ( @$critiques ) {
        my $file = delete $critique->{file};
        eval {
            $critique->{critique_info} = $perl->critique( $file,{} );
            $critique->{file_name} = $file->stringify;
            warn "Succesfully fetched critique info about $file" if $DEBUG;
            1;
        } or do {
            warn "Unable to fetch critique info about $file because $@";
        };
    }
    print encode($critiques);
}

sub extract_file_names ($source, $critiques) {
    push @$critiques , { file => $source } unless $source->stringify =~ /.*\.p[ml]$/ ;
    return;
}

sub extract_critique_info_parallely ($critiques) {
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
    my $seg_size = $MAX_PROCESS_CNT>0 ? (((@$critiques)/$MAX_PROCESS_CNT)+1) : 1;

    my @critiques_groups;
    push @critiques_groups, [ splice @$critiques, 0, $seg_size ] while @$critiques;
    my $id = 1;
    for my $cur_critiques ( @critiques_groups ) {
        my $pid = $pm->start('child_'.$id); # do the fork
        if ($pid == 0) {
            my $output_file = Path::Class::File->new( $id.'.out' );
            for my $critique( @$cur_critiques ) {
                my $file = delete $critique->{file};
                eval {
                    $critique->{critique_info} = $perl->critique( $file,{} );
                    $critique->{file_name} = $file->stringify;
                    warn "Succesfully fetched critique info about $file" if $DEBUG;
                    1;
                } or do {
                    warn "Unable to fetch critique info about $file because $@" if $DEBUG;
                };
            }
            #print encode($cur_critiques);
            $output_file->spew_lines(encode($cur_critiques));
            $pm->finish;
        }
        $id++;
    }
    $pm->wait_all_children;
    return;
}

1;
