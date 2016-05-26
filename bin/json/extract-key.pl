#!perl

use v5.22;
use warnings;

use lib 'lib';

use Getopt::Long ();

use Importer 'Code::Tooling::Util::JSON'      => qw[ decode encode ];
use Importer 'Code::Tooling::Util::Transform' => qw[ extract_key ];

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

    my $output = extract_key(
        $data, (
            key => $key,
            ($sort ? (sort => { ordering => $ordering, direction => $direction }) : ()),
            ($uniq ? (uniq => 1) : ())
        )
    );

    print encode( $output );
}

main && exit;

1;
