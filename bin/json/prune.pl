#!perl

use v5.22;
use warnings;

use lib 'lib';

use Getopt::Long ();

use Importer 'Code::Tooling::Util::JSON' => qw[ decode encode ];

our $DEBUG = 0;

sub main {

    my (@keys, $exclude);
    Getopt::Long::GetOptions(
        'key=s'   => \@keys,
        'exclude' => \$exclude,
        'verbose' => \$DEBUG
    );

    (scalar @keys != 0)
        || die 'You must specify a key set to include or exclude';

    if ( scalar @keys == 1 && $keys[0] =~ /\,/ ) {
        @keys = split /\,/ => $keys[0];
    }

    my $input = join '' => <STDIN>;
    my $data  = decode( $input );

    (ref $data eq 'ARRAY')
        || die "Can only collate JSON arrays, not:\n$input";

    my @output;
    foreach my $datum ( @$data ) {
        my %pruned;

        if ( $exclude ) {
            %pruned = %$datum;
            delete @pruned{ @keys };
        }
        else {
            @pruned{ @keys } = @{$datum}{ @keys };
        }

        push @output => \%pruned;
    }

    print encode( \@output );
}

main && exit;

1;
