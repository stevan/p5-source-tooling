#!perl

use v5.22;
use warnings;

use lib 'lib';

use Path::Class  ();
use Getopt::Long ();
use Data::Dumper ();

use Code::Tooling::Git;

use Importer 'Code::Tooling::Util::JSON' => qw[ encode ];

our $DEBUG = 0;

sub main {

    my ($checkout, $pattern);
    Getopt::Long::GetOptions(
        'checkout=s'  => \$checkout,
        # search
        'pattern=s'   => \$pattern,
        # debug
        'verbose'     => \$DEBUG,
    );

    $checkout ||= $ENV{CHECKOUT} ||= '.';

    (-e $checkout && -d $checkout)
        || die 'You must specifiy a valid checkout directory';

    $checkout = Path::Class::Dir->new( $checkout );

    my $results = Code::Tooling::Git->new(
        work_tree => $checkout
    )->grep(
        $pattern,
        {
            debug => $DEBUG
        }
    );

    print encode( $results );
}

main && exit;


1;
