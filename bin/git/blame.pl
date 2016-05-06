#!perl

use strict;
use warnings;

use lib 'lib';

use Path::Class  ();
use JSON::XS     ();
use Getopt::Long ();
use Data::Dumper ();

use Code::Tooling::Git;

our $DEBUG = 0;

sub main {

    my ($checkout, $path, $start, $end);
    Getopt::Long::GetOptions(
        'checkout=s' => \$checkout,
        'path=s'     => \$path,
        'start=i'    => \$start,
        'end=i'      => \$end,
        'verbose'    => \$DEBUG,
    );

    $checkout ||= $ENV{CHECKOUT} ||= '.';;

    (-e $checkout && -d $checkout)
        || die 'You must specifiy a valid checkout directory';

    $checkout = Path::Class::Dir->new( $checkout );
    $path     = $checkout->file( $path );

    my $blame = Code::Tooling::Git->new(
        work_tree => $checkout
    )->blame(
        $path,
        {
            start => $start,
            end   => $end,
            debug => $DEBUG
        }
    );

    print JSON::XS->new->utf8->pretty->canonical->encode( $blame );
}

main && exit;


1;
