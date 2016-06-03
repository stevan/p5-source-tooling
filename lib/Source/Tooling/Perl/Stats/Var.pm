package Source::Tooling::Perl::Stats::Var;

use v5.22;
use warnings;
use experimental 'signatures';

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';
our $DEBUG     = 0;

sub new ($class, $symbol, $value) {
    return bless {
        _symbol => $symbol,
        _value  => $value,
    } => $class;
}

# accessors

sub symbol ($self) { $self->{_symbol} }
sub value  ($self) { $self->{_value}  }

# methods

sub symbol_starts_with ($self, $substr) { index( $self->symbol, $substr ) == 0 }
sub symbol_contains    ($self, $substr) { index( $self->symbol, $substr ) >= 0 }

1;

__END__
