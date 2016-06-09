package Source::Tooling::Web::FileSystem;

use v5.22;
use warnings;
use experimental qw[
    signatures
    postderef
];

use Plack::Request;
use Path::Class ();

use Importer 'Source::Tooling::Util::JSON' => qw[ encode ];

# PSGI applications

sub list ($env) {
    my $r    = Plack::Request->new( $env );
    my $path = $env->{'source.tooling.env.CHECKOUT'}->subdir( $r->path );

    return [ 404, [], [ 'Could not find path (' . $path->stringify . ")\n" ]]
        unless -e $path;

    my $body;
    if ( -d $path ) {
        my @children = map +{
            path   => $_->basename,
            is_dir => (-d $_ ? 1 : 0)
        }, $path->children( no_hidden => 1 );

        if ( my $filter = $r->param('filter') ) {
            @children = grep $_->{path} =~ /$filter/, @children;
        }

        $body = {
            path     => $path->relative( $env->{'source.tooling.env.CHECKOUT'} )->stringify,
            is_dir   => 1,
            children => \@children
        };
    }
    else {
        $body = {
            path   => $path->relative( $env->{'source.tooling.env.CHECKOUT'} )->stringify,
            is_dir => 0,
        };
    }

    return [
        200,
        [ 'Content-Type' => 'application/json' ],
        [ encode( $body ) ]
    ];
}

sub read ($env) {
    my $r    = Plack::Request->new( $env );
    my $path = $env->{'source.tooling.env.CHECKOUT'}->subdir( $r->path );

    return [ 404, [], [ 'Could not find path (' . $path->stringify . ")\n" ]]
        unless -e $path;

    return [ 400, [], [ 'The path specified is a directory (' . $path->stringify . ")\n" ]]
        if -d $path;

    my $file = Path::Class::File->new( $path );

    my ($status, @headers, @body);

    if ( my $header = $r->headers->header('Range') ) {
        if ($header =~ /^lines\=(\d+)\-(\d+)$/) {
            my ($start, $end) = ($1, $2);

            return [ 416, [], [ 'End of range must be greater than start of range' ]]
                if $start >= $end;

            my @all  = $file->slurp;
            my $size = scalar @all;

            return [ 416, [], [ 'Start of range exceeds content length' ]]
                if $start >= $size;

            # correct the end of the range
            $end = $size if $end > $size;

            $status  = 206;
            @body    = @all[ $start .. $end ];
            @headers = ('Content-Range' => "lines ${start}-${end}/${size}");
        }
    }

    unless ( $status ) {
        # NOTE:
        # If we don't have a status, this means
        # that we either:
        # 1) didn't get a valid Range header
        # 2) it contained a range unit we didn't understand
        #     http://httpwg.org/specs/rfc7233.html
        #     `An origin server MUST ignore a Range header field that
        #     contains a range unit it does not understand.`
        $status = 200;
        @body   = $file->slurp;
    }

    return [
        200,
        [
            'Content-Type'  => 'text/plain',
            'Accept-Ranges' => 'lines',
            @headers,
        ],
        \@body
    ];
}


1;

__END__
