#!perl

use strict;
use warnings;

use lib 'lib';

use Path::Class  ();
use Getopt::Long ();
use Data::Dumper ();

use Code::Tooling::Git;

use Importer 'Code::Tooling::Util::JSON' => qw[ encode ];

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

    print encode( $log );
}

main && exit;


1;
