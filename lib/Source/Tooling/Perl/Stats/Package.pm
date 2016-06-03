package Source::Tooling::Perl::Stats::Package;

use v5.22;
use warnings;
use experimental qw[
    signatures
    postderef
];

use Scalar::Util ();

use Source::Tooling::Perl::Stats::Sub;
use Source::Tooling::Perl::Stats::Var;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';
our $DEBUG     = 0;

use parent 'Source::Tooling::Perl::Stats';

sub new ($class, $pkg) {

    (Scalar::Util::blessed( $pkg ) && $pkg->isa('PPI::Statement::Package'))
        || die 'You must pass a valid `PPI::Statement::Package` instance';

    my (@subs, @vars);
    $pkg->find(
        sub ($root, $node) {
            if ( $node->isa('PPI::Statement::Sub') ) {
                push @subs => Source::Tooling::Perl::Stats::Sub->new( $node );
                return undef; # do not descend (packages and subs cannot be nested here)
            }
            elsif ( $node->isa('PPI::Statement::Variable') && $node->type eq 'our' ) {
                foreach my $symbol ( $node->symbols ) {
                    push @vars => Source::Tooling::Perl::Stats::Var->new( $symbol );
                }
                return undef; # do not descend (duh)
            }
        }
    );

    return bless {
        _package => $pkg,
        _subs    => \@subs,
        _vars    => \@vars,
    } => $class;
}

# accessors

sub ppi  ($self) { $self->{_package}  }
sub subs ($self) { $self->{_subs}->@* }
sub vars ($self) { $self->{_vars}->@* }

# methods

sub name ($self) {
    $self->ppi->namespace
}

1;

__END__
