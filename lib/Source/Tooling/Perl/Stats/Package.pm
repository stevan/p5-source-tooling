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

use Importer 'Source::Tooling::Util::PPI' => qw[
    extract_symbols_and_values_from_variable
    extract_symbol_and_value_from_statement
    extract_sensible_value_from_token
];

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
            eval {
                if ( $node->isa('PPI::Statement::Sub') ) {
                    push @subs => Source::Tooling::Perl::Stats::Sub->new( $node );
                }
                elsif ( $node->isa('PPI::Statement::Variable') && $node->type eq 'our' ) {
                    my ($symbols, $values) = extract_symbols_and_values_from_variable( $node );
                    # ...
                    foreach my $i ( 0 .. $symbols->$#* ) {
                        push @vars => Source::Tooling::Perl::Stats::Var->new(
                            $symbols->[$i]->symbol,
                            ($values->[$i] ? extract_sensible_value_from_token( $values->[$i] ) : undef)
                        );
                    }
                }
                elsif ( $node->isa('PPI::Statement') ) {
                    my ($symbol, $value) = extract_symbol_and_value_from_statement( $node );
                    # now check this is actually related to our package
                    if ($symbol && index( $symbol->content, $pkg->namespace ) == 1 ) {
                        # if we got here, it is an implicit global
                        push @vars => Source::Tooling::Perl::Stats::Var->new(
                            $symbol->symbol,
                            ($value ? extract_sensible_value_from_token( $value ) : undef)
                        );
                    }
                }
                1;
            } or do {
                warn "Caught exception during PPI->find: $@";
                return undef;
            };
            return 0;
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

sub add_subs ($self, @subs) { push $self->{_subs}->@* => @subs }
sub add_vars ($self, @vars) { push $self->{_vars}->@* => @vars }

# methods

sub name ($self) {
    $self->ppi->namespace
}

sub version ($self) {
    foreach my $var ( $self->vars ) {
        return $var if $var->symbol_contains('VERSION');
    }
    return undef;
}

sub authority ($self) {
    foreach my $var ( $self->vars ) {
        return $var if $var->symbol_contains('AUTHORITY');
    }
    return undef;
}

1;

__END__
