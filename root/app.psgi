#!/usr/bin/env perl

use v5.22;
use warnings;

use lib 'lib';

use Plack;
use Plack::Request;
use Plack::Builder;

use Path::Class ();

use Source::Tooling::Perl;
use Source::Tooling::Git;

use Importer 'Source::Tooling::Util::JSON' => qw[ encode ];

# Constants

use constant PERLDOC_URL_TEMPLATE  => 'http://perldoc.perl.org/%s';
use constant METACPAN_URL_TEMPLATE => 'https://metacpan.org/search?search_type=modules&q=%s';

# Config

$ENV{CHECKOUT}       ||= '.';
$ENV{CRITIC_PROFILE} ||= './config/perlcritic.ini';
$ENV{PERL_VERSION}   ||= $];
$ENV{PERL_LIB_ROOT}  ||= 'lib';
$ENV{PERLDOC_BIN}    ||= 'perldoc';

# Globals

my $CHECKOUT = Path::Class::Dir->new( $ENV{CHECKOUT} );
my $PERL_LIB = $CHECKOUT->subdir( $ENV{PERL_LIB_ROOT} );

my $GIT = Source::Tooling::Git->new(
    work_tree => $CHECKOUT
);

my $PERL = Source::Tooling::Perl->new(
    perlcritic_profile => $ENV{CRITIC_PROFILE},
    perl_version       => $ENV{PERL_VERSION},
);

# ...

builder {

    enable 'CrossOrigin', origins => '*';

    mount '/fs/' => sub {
        my $r    = Plack::Request->new( $_[0] );
        my $path = $CHECKOUT->subdir( $r->path );

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
                path     => $path->relative( $CHECKOUT )->stringify,
                is_dir   => 1,
                children => \@children
            };
        }
        else {
            $body = {
                path   => $path->relative( $CHECKOUT )->stringify,
                is_dir => 0,
            };
        }

        return [
            200,
            [ 'Content-Type' => 'application/json' ],
            [ encode( $body ) ]
        ];
    };

    mount '/src/' => sub {
        my $r    = Plack::Request->new( $_[0] );
        my $path = $CHECKOUT->subdir( $r->path );

        return [ 404, [], [ 'Could not find path (' . $path->stringify . ")\n" ]]
            unless -e $path;

        return [ 400, [], [ 'The path specified is a directory (' . $path->stringify . ")\n" ]]
            if -d $path;

        return [
            200,
            [ 'Content-Type' => 'text/plain' ],
            [ Path::Class::File->new( $path )->slurp ]
        ];
    };

    mount '/perl/' => builder {
        mount '/critique/' => sub {
            my $r    = Plack::Request->new( $_[0] );
            my $path = $CHECKOUT->subdir( $r->path );

            return [ 404, [], [ 'Could not find path (' . $path->stringify . ")\n" ]]
                unless -e $path;

            return [ 400, [], [ 'The path specified is a directory (' . $path->stringify . ")\n" ]]
                if -d $path;

            return [
                200,
                [ 'Content-Type' => 'application/json' ],
                [ encode( $PERL->critique( $path, $r->query_parameters ) ) ]
            ];
        };

        mount '/doc/' => sub {
            my $r    = Plack::Request->new( $_[0] );
            my $args = $r->query_parameters;

            return [ 400, [], [ 'You must specify either a function name' ]]
                unless $args->{f};

            my @cmd  = ($ENV{PERLDOC_BIN}, '-T', '-o', 'HTML', '-f', $args->{f});
            my @html = `@cmd`;

            return [ 200, [ 'Content-Type' => 'text/html' ], [ @html ]];
        };

        mount '/module/' => builder {
            mount '/classify/' => sub {
                my $r          = Plack::Request->new( $_[0] );
                my @modules    = grep $_, split /\,/ => ($r->path =~ s/^\///r); #/
                my $classified = $PERL->classify_modules( @modules );

                # do some enhancement/fixup for the benefit
                # of a UI that is using this API
                foreach my $module ( @$classified ) {
                    my $path = $PERL_LIB->file( $module->{path} )
                                        ->relative( $CHECKOUT )
                                        ->stringify;
                    if ( -f $path ) {
                        $module->{path}     = $path;
                        $module->{is_local} = 1;
                    }
                    else {
                        $module->{is_local} = 0;
                        $module->{url}      = $module->{is_core}
                            ? (sprintf PERLDOC_URL_TEMPLATE, ($module->{path} =~ s/\.pm$/\.html/r)) #/
                            : (sprintf METACPAN_URL_TEMPLATE, $module->{name});
                        delete $module->{path};
                    }
                }

                return [
                    200,
                    [ 'Content-Type' => 'application/json' ],
                    [ encode( $classified ) ]
                ];
            };
        };
    };

    mount '/git/' => builder {
        mount '/blame/' => sub {
            my $r    = Plack::Request->new( $_[0] );
            my $path = $CHECKOUT->subdir( $r->path );

            return [ 404, [], [ "Could not run <git blame> command, file not found ($path)\n" ]]
                unless -e $path;

            return [ 400, [], [ "The <git blame> command is not allowed without a valid file path (no directories)\n" ]]
                if -d $path;

            return [
                200,
                [ 'Content-Type' => 'application/json' ],
                [ encode( $GIT->blame( $path, $r->query_parameters ) ) ]
            ];
        };

        mount '/log/' => sub {
            my $r    = Plack::Request->new( $_[0] );
            my $path = $CHECKOUT->subdir( $r->path );

            return [ 404, [], [ "Could not run <git log> command, file not found ($path)\n" ]]
                unless -e $path;

            return [ 400, [], [ "The <git log> command is not allowed without a valid file path (no directories)\n" ]]
                if -d $path;

            return [
                200,
                [ 'Content-Type' => 'application/json' ],
                [ encode( $GIT->log( $path, $r->query_parameters ) ) ]
            ];
        };

        mount '/show/' => sub {
            my $r     = Plack::Request->new( $_[0] );
            my ($sha) = grep $_, split /\// => $r->path;

            return [ 400, [], [ "The <git show> command is not allowed without a sha to view\n" ]]
                unless $sha;

            return [
                200,
                [ 'Content-Type' => 'application/json' ],
                [ encode( $GIT->show( $sha, $r->query_parameters ) ) ]
            ];
        };

        mount '/grep/' => sub {
            my $r         = Plack::Request->new( $_[0] );
            my ($pattern) = grep $_, split /\// => $r->path;

            return [ 400, [], [ "The <git grep> command requires a pattern to search with\n" ]]
                unless $pattern;

            return [
                200,
                [ 'Content-Type' => 'application/json' ],
                [ encode( $GIT->grep( $pattern, $r->query_parameters ) ) ]
            ];
        };

        mount '/' => sub {
            return [
                400,
                [],
                [ 'Unsupported git command (' . $_[0]->{PATH_INFO} . ') supported commands include ( /git/show/:sha, /git/log/:path, /git/blame/:path )' ]
            ];
        };
    };

    mount '/' => sub {
        return [ 404, [], []];
    };
};


