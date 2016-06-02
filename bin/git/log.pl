#!perl

use v5.22;
use warnings;

use lib 'lib';

use Path::Class  ();
use Getopt::Long ();
use Data::Dumper ();

use Source::Tooling::Git;

use Importer 'Source::Tooling::Util::JSON' => qw[ encode ];

our $DEBUG = 0;

sub main {

    my (
        $checkout, $path,
        $max_count, $skip,
        $since, $after, $until, $before,
        $author, $commiter,
    );

    Getopt::Long::GetOptions(
        'checkout=s'  => \$checkout,
        'path=s'      => \$path,
        'verbose'     => \$DEBUG,
        'max_count=i' => \$max_count,
        'skip=i'      => \$skip,
        'since=s'     => \$since,
        'after=s'     => \$after,
        'until=s'     => \$until,
        'before=s'    => \$before,
        'author=s'    => \$author,
        'commiter=s'  => \$commiter,
    );

    $checkout ||= $ENV{CHECKOUT} ||= '.';

    (-e $checkout && -d $checkout)
        || die 'You must specifiy a valid checkout directory';

    $checkout = Path::Class::Dir->new( $checkout );
    $path     = $checkout->file( $path );

    my $log = Source::Tooling::Git->new(
        work_tree => $checkout
    )->log(
        $path,
        {
            debug     => $DEBUG,
            max_count => $max_count,
            skip      => $skip,
            since     => $since,
            after     => $after,
            until     => $until,
            before    => $before,
            author    => $author,
            commiter  => $commiter,
        }
    );

    print encode( $log );
}

main && exit;


1;
