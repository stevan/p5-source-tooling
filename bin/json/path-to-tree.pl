#!perl

use v5.22;
use warnings;

use lib 'lib';

use Getopt::Long ();

use Importer 'Code::Tooling::Util::JSON'      => qw[ decode encode ];
use Importer 'Code::Tooling::Util::Transform' => qw[ path_to_tree ];

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

    my $root = path_to_tree(
        $data, (
            path_key       => $path_key,
            path_seperator => $path_seperator,
        )
    );

    print encode( $root );
}

main && exit;

1;
