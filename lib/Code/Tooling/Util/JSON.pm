package Code::Tooling::Util::JSON;

use v5.22;
use warnings;
use experimental 'signatures';

use JSON::XS;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';
our $DEBUG     = 0;

our @EXPORT_OK = qw[
    &encode
    &decode
];

our $JSON = JSON::XS->new->utf8->pretty->canonical;

sub encode ($data) { $JSON->encode( $data ) }
sub decode ($json) { $JSON->decode( $json ) }

1;

__END__
