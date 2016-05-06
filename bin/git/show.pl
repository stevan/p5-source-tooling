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

    my ($checkout, $sha);
    Getopt::Long::GetOptions(
        'checkout=s' => \$checkout,
        'sha=s'      => \$sha,
        'verbose'    => \$DEBUG,
    );

    $checkout ||= $ENV{CHECKOUT} ||= '.';;

    (-e $checkout && -d $checkout)
        || die 'You must specifiy a valid checkout directory';

    my $log = Code::Tooling::Git->new(
        work_tree => $checkout
    )->show(
        $sha,
        {
            debug => $DEBUG
        }
    );

    print JSON::XS->new->utf8->pretty->canonical->encode( $log );
}

main && exit;


1;
