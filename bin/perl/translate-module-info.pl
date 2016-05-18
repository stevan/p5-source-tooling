#!perl

use strict;
use warnings;

use lib 'lib';

use Data::Dumper ();
use Path::Class  ();

use Importer 'Code::Tooling::Util::JSON' => qw[ decode ];

sub main {
    my $file = Path::Class::File->new( 'report.json' );
    my $content = $file->slurp;
    my $modules = decode($content);
    for my $module ( @$modules ) {
        print "---------analyzing module",$module->{namespace},"---------","\n";
        if(!keys $module->{meta}->{cpan}) {
            print "holy shit this has no entry in cpan!!!! ","\n";
        }
        if( defined $module->{meta}->{cpan}
            && defined $module->{meta}->{cpan}->{version_numified}
            && defined $module->{meta}->{version}) {
            my $version_difference = $module->{meta}->{cpan}->{version_numified} - $module->{meta}->{version};
            print "versions differ by ",$version_difference,"\n" if($version_difference>0);
        }
        print "------------------------------------------------------","\n";
    }
}

main && exit;
1;
