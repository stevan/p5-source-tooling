#!perl

use v5.22;
use warnings;

use lib 'lib';

use Getopt::Long ();

use Importer 'Code::Tooling::Util::JSON' => qw[ decode encode ];

our $DEBUG = 0;

sub main {

    my ($key);
    Getopt::Long::GetOptions(
        'key=s'   => \$key,
        'verbose' => \$DEBUG
    );

    ($key) || die 'Must provide a key to group-by';

    my $input = join '' => <STDIN>;
    my $data  = decode( $input );

    (ref $data eq 'ARRAY')
        || die "Can only collate JSON arrays, not:\n$input";

    my %output;
    foreach my $datum ( @$data ) {
        (exists $datum->{$key})
            || die "Could not find key($key) in data(" . encode( $datum ) . ")";

        $output{ $datum->{$key} } = [] unless $output{ $datum->{$key} };
        push @{ $output{ $datum->{$key} } } => $datum;
    }

    print encode( \%output );
}

main && exit;

1;
