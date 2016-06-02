package Source::Tooling::Perl::Stats::File;

use v5.22;
use warnings;
use experimental qw[
    signatures
    postderef
];

use PPI;
use PPI::Document;

use Source::Tooling::Perl::Stats::Package;
use Source::Tooling::Perl::Stats::Sub;
use Source::Tooling::Perl::Stats::Var;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';
our $DEBUG     = 0;

sub new ($class, @args) {

    my $e = PPI::Document->new( @args )
        or die 'Unable to parse (' . (join ', ' => @args) . ')';

    my $ppi_packages = $e->find('PPI::Statement::Package');
    my $ppi_subs     = $e->find('PPI::Statement::Sub');

    my (@packages, @subs);

    @packages = map Source::Tooling::Perl::Stats::Package->new($_), $ppi_packages->@*
        if ref $ppi_packages;

    @subs = map Source::Tooling::Perl::Stats::Sub->new($_), $ppi_subs->@*
        if ref $ppi_subs;

    return bless {
        _ppi      => $e,
        _packages => \@packages,
        _subs     => \@subs,
    } => $class;
}

sub packages ($self) { $self->{_packages}->@* }
sub subs     ($self) { $self->{_subs}->@*     }

1;

__END__
