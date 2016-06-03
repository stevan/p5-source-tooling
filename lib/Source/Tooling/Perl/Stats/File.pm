package Source::Tooling::Perl::Stats::File;

use v5.22;
use warnings;
use experimental qw[
    signatures
    postderef
];

use PPI;
use PPI::Document;

use Data::Dumper ();

use Source::Tooling::Perl::Stats::Package;
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

sub new ($class, @args) {

    my $doc = PPI::Document->new( @args )
        or die 'Unable to parse (' . (join ', ' => @args) . ')';

    my (@packages, @subs, @vars);
    $doc->find(
        sub ($root, $node) {
            if ( $node->isa('PPI::Statement::Package') ) {
                push @packages => Source::Tooling::Perl::Stats::Package->new( $node );
                return undef; # do not recurse
            }
            elsif ( $node->isa('PPI::Statement::Sub') ) {
                push @subs => Source::Tooling::Perl::Stats::Sub->new( $node );
            }
            elsif ( $node->isa('PPI::Statement::Variable') && $node->type eq 'our' ) {
                my ($symbols, $values) = extract_symbols_and_values_from_variable( $node );

                foreach my $i ( 0 .. $symbols->$#* ) {
                    push @vars => Source::Tooling::Perl::Stats::Var->new(
                        $symbols->[$i]->symbol,
                        ($values->[$i] ? extract_sensible_value( $values->[$i] ) : undef)
                    );
                }
            }

            return 0; # do not descend, but keep matching (duh)
        }
    );

    return bless {
        _document => $doc,
        _packages => \@packages,
        _subs     => \@subs,
        _vars     => \@vars,
    } => $class;
}

# accessors

sub ppi      ($self) { $self->{_document}     }
sub packages ($self) { $self->{_packages}->@* }
sub subs     ($self) { $self->{_subs}->@*     }
sub vars     ($self) { $self->{_vars}->@*     }

1;

__END__
