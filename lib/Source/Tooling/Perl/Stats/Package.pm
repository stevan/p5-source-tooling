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
    extract_sensible_value
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
            if ( $node->isa('PPI::Statement::Sub') ) {
                push @subs => Source::Tooling::Perl::Stats::Sub->new( $node );
            }
            elsif ( $node->isa('PPI::Statement::Variable') && $node->type eq 'our' ) {
                my ($symbols, $values) = extract_symbols_and_values_from_variable( $node );

                #use Data::Dumper;
                #warn Dumper [ $symbols, $values ];

                #eval {
                foreach my $i ( 0 .. $symbols->$#* ) {
                    push @vars => Source::Tooling::Perl::Stats::Var->new(
                        $symbols->[$i]->symbol,
                        ($values->[$i] ? extract_sensible_value( $values->[$i] ) : undef)
                    );
                }
                #}; warn $@ if $@;
            }
            elsif ( $node->isa('PPI::Statement') ) {
                my $sym = $node->schild(0);

                # ignore this statement unless ...
                return '' unless Scalar::Util::blessed($sym)        # we find something
                              && $sym->isa('PPI::Token::Symbol')    # and it is a symbol
                              && index( $sym->content, '::' ) >= 0; # and it has :: in it

                my $op = $sym->snext_sibling;

                # ignore this statement unless ...
                return '' unless Scalar::Util::blessed($op)        # we find something
                              && $op->isa('PPI::Token::Operator')  # and it is an operator
                              && $op->content eq '=';              # and it is assignment

                # now check this is actually related to our package
                return '' unless index( $sym->content, $pkg->namespace ) == 1;

                my $value = $op->snext_sibling;

                # if we got here, it is an implicit global
                push @vars => Source::Tooling::Perl::Stats::Var->new(
                    $sym->symbol,
                    ($value ? extract_sensible_value( $value ) : undef)
                );
            }

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
