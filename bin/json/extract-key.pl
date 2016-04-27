#!perl

use strict;
use warnings;

use JSON::XS     ();
use Getopt::Long ();

our $DEBUG = 0;

sub main {

    my ($key);
    Getopt::Long::GetOptions(
        'key=s'   => \$key,
        'verbose' => \$DEBUG
    );

    ($key) || die 'Must provide a key to group-by';

    my $input = join '' => <STDIN>;
    my $json  = JSON::XS->new->utf8->pretty->canonical;

    my $data = $json->decode( $input );

    (ref $data eq 'ARRAY')
        || die "Can only collate JSON arrays, not:\n$input";

    my @output;
    foreach my $datum ( @$data ) {
        (exists $datum->{$key})
            || die "Could not find key($key) in data(" . $json->encode( $datum ) . ")";

        push @output => $datum->{$key};
    }

    print $json->encode( \@output );
}

main && exit;

1;
