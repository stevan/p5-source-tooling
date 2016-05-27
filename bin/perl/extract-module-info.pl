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

use Importer 'Code::Tooling::Util::JSON'       => qw[ encode ];
use Importer 'Code::Tooling::Util::FileSystem' => qw[ traverse_filesystem ];

our $DEBUG = 0;
our $ROOT;

sub main {

    my ($exclude, $include);
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

    my $perl = Code::Tooling::Perl->new;

    # The data structure within @modules is
    # as follows:
    # {
    #     namespace : String,    # name of the package
    #     line_num  : Int,       # line number package began at
    #     path      : Str,       # path of the file package was in
    #     version   : VString    # value of $VERSION
    # }

    my @modules;
    traverse_filesystem(
        $ROOT,
        sub ($source, $acc) { push @$acc => $perl->extract_module_info( $source )->@* },
        \@modules,
        (
            ($exclude ? (exclude => $exclude) : ()),
            ($include ? (include => $include) : ()),
        )
    );

    print encode( \@modules );
}

main && exit;

1;
