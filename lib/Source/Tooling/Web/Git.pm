package Source::Tooling::Web::Git;

use v5.22;
use warnings;
use experimental qw[
    signatures
    postderef
];

use Plack::Request;
use Path::Class ();

use Importer 'Source::Tooling::Util::JSON' => qw[ encode ];

# PSGI Applications

sub blame ($env) {
    my $r    = Plack::Request->new( $env );
    my $path = $env->{'source.tooling.env.CHECKOUT'}->subdir( $r->path );

    return [ 404, [], [ "Could not run <git blame> command, file not found ($path)\n" ]]
        unless -e $path;

    return [ 400, [], [ "The <git blame> command is not allowed without a valid file path (no directories)\n" ]]
        if -d $path;

    return [
        200,
        [ 'Content-Type' => 'application/json' ],
        [ encode( $env->{'source.tooling.obj.GIT'}->blame( $path, $r->query_parameters ) ) ]
    ];
}

sub log ($env) {
    my $r    = Plack::Request->new( $env );
    my $path = $env->{'source.tooling.env.CHECKOUT'}->subdir( $r->path );

    return [ 404, [], [ "Could not run <git log> command, file not found ($path)\n" ]]
        unless -e $path;

    return [ 400, [], [ "The <git log> command is not allowed without a valid file path (no directories)\n" ]]
        if -d $path;

    return [
        200,
        [ 'Content-Type' => 'application/json' ],
        [ encode( $env->{'source.tooling.obj.GIT'}->log( $path, $r->query_parameters ) ) ]
    ];
}

sub show ($env) {
    my $r     = Plack::Request->new( $env );
    my ($sha) = grep $_, split /\// => $r->path;

    return [ 400, [], [ "The <git show> command is not allowed without a sha to view\n" ]]
        unless $sha;

    return [
        200,
        [ 'Content-Type' => 'application/json' ],
        [ encode( $env->{'source.tooling.obj.GIT'}->show( $sha, $r->query_parameters ) ) ]
    ];
}

sub grep ($env) {
    my $r         = Plack::Request->new( $env );
    my ($pattern) = grep $_, split /\// => $r->path;

    return [ 400, [], [ "The <git grep> command requires a pattern to search with\n" ]]
        unless $pattern;

    return [
        200,
        [ 'Content-Type' => 'application/json' ],
        [ encode( $env->{'source.tooling.obj.GIT'}->grep( $pattern, $r->query_parameters ) ) ]
    ];
}

1;

__END__
