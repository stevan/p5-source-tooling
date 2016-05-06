package Code::Tooling::Util::JSON;

use strict;
use warnings;

use Exporter 'import';
use JSON::XS;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

our @EXPORT = qw[
    encode
    decode
];

our $JSON = JSON::XS->new->utf8->pretty->canonical;

sub encode { $JSON->encode( @_ ) }
sub decode { $JSON->decode( @_ ) }

1;

__END__
