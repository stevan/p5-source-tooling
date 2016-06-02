package Source::Tooling::Perl::Stats::Package;

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

1;

__END__
