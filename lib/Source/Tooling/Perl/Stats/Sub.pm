package Source::Tooling::Perl::Stats::Sub;

use v5.22;
use warnings;
use experimental 'signatures';

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';
our $DEBUG     = 0;

sub new ($class, $e) {
    return bless {
        _ppi  => $e,
    } => $class;
}

sub name ($self) {
    $self->{_ppi}->name
}

1;

__END__
