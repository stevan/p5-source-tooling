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

    (Scalar::Util::blessed( $var ) && $var->isa('PPI::Statement::Sub'))
        || die 'You must pass a valid `PPI::Statement::Sub` instance';

    return bless {
        _var => $var,
    } => $class;
}

1;

__END__
