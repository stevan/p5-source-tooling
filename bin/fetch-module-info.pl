#!perl

use strict;
use warnings;

use JSON::XS     ();
use Getopt::Long ();
use Data::Dumper ();

use MetaCPAN::Client;

our $DEBUG = 0;

sub main {

    my ($exclude, $include);
    Getopt::Long::GetOptions(
        'verbose' => \$DEBUG,
    );

    my $input = join '' => <STDIN>;
    my $json  = JSON::XS->new->utf8->pretty->canonical;

    my $data = $json->decode( $input );

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

    print $json->encode( \@info );
}

main && exit;

# subs ....


1;
