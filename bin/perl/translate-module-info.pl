#!perl

use strict;
use warnings;

use lib 'lib';

use Data::Dumper ();

use JSON::XS qw(encode_json decode_json);
use Code::Tooling::Util::JSON qw[ encode ];
use File::Slurp qw(read_file write_file);

sub main {
    my $json = read_file('report.json', { binmode => ':raw' });
    my $modules = decode_json $json;
    for my $module ( @$modules ) {
        print "---------analyzing module",$module->{namespace},"---------","\n";
        if(!keys $module->{meta}->{cpan}) {
            print "holy shit this has no entry in cpan!!!! ","\n";

        }
        print "------------------------------------------------------","\n";
    }
}

main && exit;
1;
