#!perl

use strict;
use warnings;

use lib 'lib';

use Getopt::Long ();

use Code::Tooling::Util::JSON qw[ decode encode ];

our $DEBUG = 0;

sub main {

    my ($key, $sort);
    Getopt::Long::GetOptions(
        'key=s'   => \$key,
        'sort'    => \$sort,
        'verbose' => \$DEBUG
    );

    ($key) || die 'Must provide a key to group-by';

    my $input = join '' => <STDIN>;
    my $data  = decode( $input );

    (ref $data eq 'ARRAY')
        || die "Can only collate JSON arrays, not:\n$input";

    my @output;
    foreach my $datum ( @$data ) {
        (exists $datum->{$key})
            || die "Could not find key($key) in data(" . encode( $datum ) . ")";

        push @output => $datum->{$key};
    }

    @output = sort @output if $sort;

    print encode( \@output );
}

main && exit;

1;
