#!perl

use v5.22;
use warnings;
use experimental qw[
    signatures
    current_sub
    postderef
    say
];

use lib 'lib';

use Getopt::Long ();

use Importer 'Source::Tooling::Util::JSON' => qw[ decode encode ];

our $DEBUG = 0;
our %ACC_TYPES = (
    ARRAY => sub { [] },
    HASH  => sub { {} },
);

sub main {

    my ($f, $acc);
    Getopt::Long::GetOptions(
        'f=s'     => \$f,
        'acc=s'   => \$acc,
        'verbose' => \$DEBUG
    );

    (defined $f)
        || die 'You must pass a function to map';

    (exists $ACC_TYPES{ $acc })
        || die 'Invalid accumulator type: ' . $acc;

    my $src = '$f = sub ($e, $acc) { '.$f.'; }';

    (eval $src && ref $f eq 'CODE')
        || die 'Unable to compile function: ' . $f . ' because: ' . $@;

    my $input = join '' => <STDIN>;
    my $data  = decode( $input );

    (ref $data eq 'ARRAY')
        || die "Can only collate JSON arrays, not:\n$input";

    $acc = $ACC_TYPES{ $acc }->();
    $f->($_, $acc) foreach @$data;

    print encode( $acc );
}

main && exit;

1;
