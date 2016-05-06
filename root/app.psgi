#!/usr/bin/env perl

use strict;
use warnings;

use Plack;
use Plack::Request;
use Plack::MIME;
use Plack::Builder;

use Path::Class ();
use JSON::XS    ();

use Code::Tooling::Perl;
use Code::Tooling::Git;

$ENV{CHECKOUT}       ||= '.';
$ENV{CRITIC_PROFILE} ||= './config/perlcritic.ini';

my $CHECKOUT = Path::Class::Dir->new( $ENV{CHECKOUT} );
my $JSON     = JSON::XS->new->utf8->pretty->canonical;
my $GIT      = Code::Tooling::Git->new( work_tree => $CHECKOUT );
my $PERL     = Code::Tooling::Perl->new( perlcritic_profile => $ENV{CRITIC_PROFILE} );

builder {

    #enable 'CrossOrigin', origins => '*';

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
            [ $JSON->encode( $body ) ]
        ];
    };

    mount '/src/' => sub {
        my $r    = Plack::Request->new( $_[0] );
        my $path = $CHECKOUT->subdir( $r->path );

        return [ 404, [], [ 'Could not find path (' . $path->stringify . ")\n" ]]
            unless -e $path;

        return [ 400, [], [ 'The path specified is a directory (' . $path->stringify . ")\n" ]]
            if -d $path;

        my $file = Path::Class::File->new( $path );
        my $mime = Plack::MIME->mime_type( $file->basename );

        return [
            200,
            [ 'Content-Type' => $mime ],
            [ $file->slurp ]
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
                [ $JSON->encode( $PERL->critique( $path, $r->query_parameters ) ) ]
            ];
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
                [ $JSON->encode( $GIT->blame( $path, $r->query_parameters ) ) ]
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
                [ $JSON->encode( $GIT->log( $path, $r->query_parameters ) ) ]
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
                [ $JSON->encode( $GIT->show( $sha, $r->query_parameters ) ) ]
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


