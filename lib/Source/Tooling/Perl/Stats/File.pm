package Source::Tooling::Perl::Stats::File;

use v5.22;
use warnings;
use experimental qw[
    signatures
    postderef
];

use PPI;
use PPI::Document;

use Source::Tooling::Perl::Stats::Package;
use Source::Tooling::Perl::Stats::Sub;
use Source::Tooling::Perl::Stats::Var;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';
our $DEBUG     = 0;

use parent 'Source::Tooling::Perl::Stats';

sub new ($class, @args) {

    my $doc = PPI::Document->new( @args )
        or die 'Unable to parse (' . (join ', ' => @args) . ')';

    my (@packages, @subs);
    $doc->find(
        sub ($root, $node) {
            if ( $node->isa('PPI::Statement::Package') ) {
                push @packages => Source::Tooling::Perl::Stats::Package->new( $node );
                return undef; # do not descend (let the package object do that)
            }
            elsif ( $node->isa('PPI::Statement::Sub') ) {
                push @subs => Source::Tooling::Perl::Stats::Sub->new( $node );
                return undef; # do not descend (packages and subs cannot be nested here)
            }
        }
    );

    return bless {
        _document => $doc,
        _packages => \@packages,
        _subs     => \@subs,
    } => $class;
}

sub ppi      ($self) { $self->{_document}     }
sub packages ($self) { $self->{_packages}->@* }
sub subs     ($self) { $self->{_subs}->@*     }

1;

__END__
