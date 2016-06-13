package Source::Tooling::Perl::Stats;

use v5.22;
use warnings;
use experimental 'signatures';

use PPI;
use PPI::Dumper;

our $VERSION     = '0.01';
our $AUTHORITY   = 'cpan:STEVAN';
our $DEBUG       = 0;
our $IS_ABSTRACT = 1;

sub ppi;

sub ppi_dump ($self) { PPI::Dumper->new( $self->ppi )->string }

sub source      ($self) { $self->ppi->content }
sub line_count  ($self) { scalar split /\n/ => $self->source }
sub line_number ($self) { $self->ppi->line_number }

1;

__END__
