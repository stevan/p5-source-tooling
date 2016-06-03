package Source::Tooling::Perl::Stats::Sub;

use v5.22;
use warnings;
use experimental 'signatures';

use Scalar::Util ();

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';
our $DEBUG     = 0;

use parent 'Source::Tooling::Perl::Stats';

sub new ($class, $sub) {

    (Scalar::Util::blessed( $sub ) && $sub->isa('PPI::Statement::Sub'))
        || die 'You must pass a valid `PPI::Statement::Sub` instance';

    return bless {
        _sub  => $sub,
    } => $class;
}

sub ppi { $_[0]->{_sub} }

sub name ($self) {
    $self->ppi->name
}

1;

__END__
