#!perl

use strict;
use warnings;

use lib 'lib';

use experimental 'postderef';

use List::Util   ();
use Getopt::Long ();
use Data::Dumper ();

use Importer 'Code::Tooling::Util::JSON' => qw[ decode encode ];

our $DEBUG = 0;

sub main {

    my ($path_key, $path_seperator) = ('path', '/');
    Getopt::Long::GetOptions(
        'path_key=s' => \$path_key,
        'path_sep=s' => \$path_seperator,
        'verbose'    => \$DEBUG
    );

    my $input = join '' => <STDIN>;
    my $data  = decode( $input );

    (ref $data eq 'ARRAY')
        || die "Can only collate JSON arrays, not:\n$input";

    my $root = {
        node     => 'ROOT',
        children => [],
    };

    foreach my $datum ( @$data ) {
        warn "got the path: $datum->{ $path_key }" if $DEBUG;
        my @path = split $path_seperator, $datum->{ $path_key };

        my $current = $root;
        while ( my $part = shift @path ) {

            if ( my $match = List::Util::first { $_->{node} eq $part } $current->{children}->@* ) {
                warn "GOT MATCH: " . Data::Dumper::Dumper( $match ) if $DEBUG;
                $current = $match;
            }
            else {
                warn 'No current node, creating one!' if $DEBUG;
                my $new = {
                    node     => $part,
                    children => []
                };
                warn 'Adding new node to old current node' if $DEBUG;
                push $current->{children}->@* => $new;
                $current = $new;
            }
        }

        $current->{meta} = $datum;
    }

    print encode( $root );
}

main && exit;

1;
