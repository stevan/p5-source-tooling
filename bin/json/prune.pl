#!perl

use v5.22;
use warnings;

use lib 'lib';

use Getopt::Long ();

use Importer 'Code::Tooling::Util::JSON'      => qw[ decode encode ];
use Importer 'Code::Tooling::Util::Transform' => qw[ prune ];

our $DEBUG = 0;

sub main {

    my (@keys, $exclude);
    Getopt::Long::GetOptions(
        'key=s'   => \@keys,
        'exclude' => \$exclude,
        'verbose' => \$DEBUG
    );

    (scalar @keys != 0)
        || die 'You must specify a key set to include or exclude';

    if ( scalar @keys == 1 && $keys[0] =~ /\,/ ) {
        @keys = split /\,/ => $keys[0];
    }

    my $input = join '' => <STDIN>;
    my $data  = decode( $input );

    (ref $data eq 'ARRAY')
        || die "Can only collate JSON arrays, not:\n$input";

    my $output = prune(
        $data, (
            exclude => $exclude,
            keys    => \@keys,
        )
    );

    print encode( $output );
}

main && exit;

1;
