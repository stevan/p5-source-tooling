package Source::Tooling::Perl::Stats::Package;

use v5.22;
use warnings;
use experimental qw[
    signatures
    postderef
];

use Source::Tooling::Perl::Stats::Sub;
use Source::Tooling::Perl::Stats::Var;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';
our $DEBUG     = 0;

sub new ($class, $e) {
    return bless {
        _ppi => $e,
    } => $class;
}

sub namespace ($self) {
    $self->{_ppi}->namespace
}

1;

__END__
