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

use Source::Tooling::Perl;

use Importer 'Source::Tooling::Util::JSON'       => qw[ encode ];
use Importer 'Source::Tooling::Util::FileSystem' => qw[ traverse_filesystem ];

our $DEBUG = 0;
our $ROOT;

$ENV{CRITIC_PROFILE} ||= './config/perlcritic.ini';
$ENV{PERL_VERSION}   ||= $];

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

    my $perl = Source::Tooling::Perl->new(
        perlcritic_profile => $ENV{CRITIC_PROFILE},
        perl_version       => $ENV{PERL_VERSION},
    );

    my @critiques;
    traverse_filesystem(
        $ROOT,
        sub ($source, $acc) {
            # skip non-perl files
            return unless $source->basename =~ /\.p[m|l]$/;
            # collect the rest ...
            push @$acc => $perl->critique( $source, {} );
            return;
        },
        \@critiques,
        (
            ($exclude ? (exclude => $exclude) : ()),
            ($include ? (include => $include) : ()),
        )
    );

    print encode( \@critiques );
}

main && exit;

1;

