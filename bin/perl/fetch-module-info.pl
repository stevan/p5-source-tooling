#!perl

use strict;
use warnings;

use Getopt::Long ();
use Data::Dumper ();

use Code::Tooling::Util::JSON qw[ decode encode ];

use MetaCPAN::Client;

our $DEBUG = 0;

sub main {

    my ($exclude, $include);
    Getopt::Long::GetOptions(
        'verbose' => \$DEBUG,
    );

    my $input = join '' => <STDIN>;
    my $data  = decode( $input );

    (ref $data eq 'ARRAY')
        || die "Can only collate JSON arrays, not:\n$input";

    my $mcpan = MetaCPAN::Client->new;

    my @info;
    foreach my $module ( @$data ) {
        warn "Going to fetch data about $module" if $DEBUG;
        eval {
            my $data = $mcpan->module( $module );
            push @info => $data->{data};
            warn "Succesfully fetch data about $module" if $DEBUG;
            1;
        } or do {
            warn "Unable to fetch data about $module" if $DEBUG;
        };
    }

    warn Data::Dumper::Dumper( \@info ) if $DEBUG;

    print encode( \@info );
}

main && exit;

# subs ....


1;
