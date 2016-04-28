#!perl

use strict;
use warnings;

use lib 'lib';

use Path::Class  ();
use JSON::XS     ();
use Getopt::Long ();
use Data::Dumper ();

use Git::Repository;

use code::tooling::git;

our $DEBUG = 0;

sub main {

    my ($checkout, $path);
    Getopt::Long::GetOptions(
        'checkout=s' => \$checkout,
        'path=s'     => \$path,
        'verbose'    => \$DEBUG,
    );

    $checkout ||= $ENV{CHECKOUT} ||= '.';;

    (-e $checkout && -d $checkout)
        || die 'You must specifiy a valid checkout directory';

    $checkout = Path::Class::Dir->new( $checkout );
    $path     = $checkout->file( $path );

    my $log = code::tooling::git::log(
        Git::Repository->new( work_tree => $checkout ),
        $path,
        {
            debug => $DEBUG
        }
    );

    print JSON::XS->new->utf8->pretty->canonical->encode( $log );
}

main && exit;


1;
