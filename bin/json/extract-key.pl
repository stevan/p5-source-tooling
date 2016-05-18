#!perl

use v5.22;
use warnings;

use lib 'lib';

use Getopt::Long ();
use List::Util 1.45 ();

use Importer 'Code::Tooling::Util::JSON' => qw[ decode encode ];

our $DEBUG = 0;

sub main {

    my ($key, $sort, $uniq);
    Getopt::Long::GetOptions(
        'key=s'   => \$key,
        'sort=s'  => \$sort,
        'uniq'    => \$uniq,
        'verbose' => \$DEBUG
    );

    ($key) || die 'Must provide a key to group-by';

    my ($ordering, $direction);
    if ( $sort ) {
        if ( $sort =~ /^(str|num)$/ ) {
            $ordering  = $1;
            $direction = 'asc';
        }
        elsif ( $sort =~ /^(str|num)\:(asc|desc)$/ ) {
            $ordering  = $1;
            $direction = $2;
        }
        else {
            die "Unrecognized sort option format: $sort";
        }
    }

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

    if ( $sort ) {
        @output = sort @output               if $ordering eq 'str';
        @output = sort { $a <=> $b } @output if $ordering eq 'num';
        @output = reverse @output            if $direction eq 'desc';
    }

    if ( $uniq ) {
        if ( $ordering ) {
            @output = List::Util::uniqstr( @output ) if $ordering eq 'str';
            @output = List::Util::uniqnum( @output ) if $ordering eq 'num';
        }
        else {
            @output = List::Util::uniq( @output );
        }
    }

    print encode( \@output );
}

main && exit;

1;
