package Source::Tooling::Perl::Stats::Var;

use v5.22;
use warnings;
use experimental 'signatures';

use Scalar::Util ();

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';
our $DEBUG     = 0;

use parent 'Source::Tooling::Perl::Stats';

sub new ($class, $var) {

    (Scalar::Util::blessed( $var ) && $var->isa('PPI::Token::Symbol'))
        || die 'You must pass a valid `PPI::Token::Symbol` instance';

    return bless {
        _var => $var,
    } => $class;
}

# accessors

sub ppi ($self) { $self->{_var} }

# methods

sub name ($self) { $self->ppi->symbol }

1;

__END__
