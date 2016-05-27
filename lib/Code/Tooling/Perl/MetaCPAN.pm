package Code::Tooling::Perl::MetaCPAN;

use v5.22;
use warnings;
use experimental 'signatures';

use MetaCPAN::Client;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';
our $DEBUG     = 0;

sub new ($class, %args) {

    my $client = MetaCPAN::Client->new( %args );

    return bless {
        _client => $client,
    } => $class;
}

# ...

sub get_author_info ($self, $author, %args) { $self->{_client}->author( $author, \%args ) }
sub get_module_info ($self, $module, %args) { $self->{_client}->module( $module, \%args ) }
sub get_file_source ($self, $author, $release, $path) {
    $self->{_client}
         ->ua
         ->get( sprintf 'https://api.metacpan.org/source/%s/%s/%s' => ($author, $release, $path) )
         ->{content}
}

1;

__END__
