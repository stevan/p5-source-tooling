package Source::Tooling::Perl::Stats::File;

use v5.22;
use warnings;
use experimental qw[
    signatures
    postderef
];

use PPI;
use PPI::Document;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';
our $DEBUG     = 0;

sub new ($class, $path) {

    (-e $path)
        || die 'You must pass a valid path, could not locate (' . $path . ')';

    my $doc = PPI::Document->new( $path )
        or die 'Unable to parse file (' . $path . ')';

    my $ppi_packages = $doc->find('PPI::Statement::Package');
    my $ppi_subs     = $doc->find('PPI::Statement::Sub');

    my (@packages, @subs);

    @packages = map Source::Tooling::Perl::Stats::Package->new($_), $ppi_packages->@*
        if ref $ppi_packages;

    @subs = map Source::Tooling::Perl::Stats::Sub->new($_), $ppi_subs->@*
        if ref $ppi_subs;

    return bless {
        _ppi      => $doc,
        _packages => \@packages,
        _subs     => \@subs,
    } => $class;
}

1;

__END__
