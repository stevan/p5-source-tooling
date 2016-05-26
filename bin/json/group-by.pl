#!perl

use v5.22;
use warnings;

use lib 'lib';

use Getopt::Long ();

use Importer 'Code::Tooling::Util::JSON'      => qw[ decode encode ];
use Importer 'Code::Tooling::Util::Transform' => qw[ group_by ];

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

    my $output = group_by(
        $data, (
            key => $key
        )
    );

    print encode( $output );
}

main && exit;

1;
