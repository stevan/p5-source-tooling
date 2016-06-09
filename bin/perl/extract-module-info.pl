#!perl

use v5.22;
use warnings;

use lib 'lib';

use experimental qw[
    signatures
    postderef
];

use Path::Class  ();
use Getopt::Long ();
use Data::Dumper ();

use Source::Tooling::Perl::Stats::File;

use Importer 'Source::Tooling::Util::JSON'       => qw[ encode ];
use Importer 'Source::Tooling::Util::FileSystem' => qw[ traverse_filesystem ];

our $DEBUG = 0;
our $ROOT;

sub main {

    my ($exclude, $include);
    Getopt::Long::GetOptions(
        'root=s'    => \$ROOT,
        # filters
        'exclude=s' => \$exclude,
        'include=s' => \$include,
        # development
        'verbose'   => \$DEBUG,
    );

    (-e $ROOT && -d $ROOT)
        || die 'You must specifiy a valid root directory';

    $ROOT = Path::Class::Dir->new( $ROOT );

    (defined $include && defined $exclude)
        && die 'You can not have both include and exclude patterns';

    # The data structure within @modules is
    # as follows:
    # {
    #     source   => Path, # this is the path to a given file
    #     packages => [
    #         {
    #             line_num  => Int,       # line at which the package defintion starts
    #             name      => Str,       # name of the package
    #             meta      => {
    #                 version   => Version,   # version of the given package
    #                 authority => Authority, # authority of the given package
    #             }
    #         },
    #         ...
    #     ]
    # }

    my @modules;
    traverse_filesystem(
        $ROOT,
        sub ($source, $acc) {
            # skip non-perl files
            return unless $source->basename =~ /\.[pm|pl|t]$/;

            my $f = Source::Tooling::Perl::Stats::File->new( $source->stringify );
            push @$acc => {
                source   => $source->stringify,
                packages => [
                    map +{
                        line_num => $_->line_number,
                        name     => $_->name,
                        meta     => {
                            version   => ($_->version   ? $_->version->value   : undef),
                            authority => ($_->authority ? $_->authority->value : undef),
                        }
                    }, $f->packages
                ]
            };
            return;
        },
        \@modules,
        (
            ($exclude ? (exclude => $exclude) : ()),
            ($include ? (include => $include) : ()),
        )
    );

    print encode( \@modules );
}

main && exit;

1;
