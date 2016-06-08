#!/usr/bin/env perl

use v5.22;
use warnings;

use lib 'lib';

use Plack;
use Plack::Builder;

use Path::Class ();

use Source::Tooling::Perl;
use Source::Tooling::Git;

use Source::Tooling::Web::FileSystem;
use Source::Tooling::Web::Perl;
use Source::Tooling::Web::Git;

# Config

$ENV{CHECKOUT}       ||= '.';
$ENV{CRITIC_PROFILE} ||= './config/perlcritic.ini';
$ENV{PERL_VERSION}   ||= $];
$ENV{PERL_LIB_ROOT}  ||= 'lib';
$ENV{PERLDOC_BIN}    ||= 'perldoc';

# ...

builder {

    enable 'CrossOrigin', origins => '*';

    enable sub {
        my $app = shift;
        sub {
            my $env = shift;
            $env->{'source.tooling.env.CHECKOUT'}      = Path::Class::Dir->new( $ENV{CHECKOUT} );
            $env->{'source.tooling.env.PERL_LIB_ROOT'} = $env->{'source.tooling.env.CHECKOUT'}->subdir( $ENV{PERL_LIB_ROOT} );
            $env->{'source.tooling.env.PERLDOC_BIN'}   = $ENV{PERLDOC_BIN};
            $env->{'source.tooling.obj.GIT'}           = Source::Tooling::Git->new( work_tree => $env->{'source.tooling.env.CHECKOUT'} );
            $env->{'source.tooling.obj.PERL'}          = Source::Tooling::Perl->new(
                perlcritic_profile => $ENV{CRITIC_PROFILE},
                perl_version       => $ENV{PERL_VERSION},
            );
            return $app->($env);
        };
    };

    mount '/fs/'  => \&Source::Tooling::Web::FileSystem::list;
    mount '/src/' => \&Source::Tooling::Web::FileSystem::read;

    mount '/perl/' => builder {
        mount '/critique/'        => \&Source::Tooling::Web::Perl::critique;
        mount '/doc/'             => \&Source::Tooling::Web::Perl::perldoc;
        mount '/module/classify/' => \&Source::Tooling::Web::Perl::classify_module;
    };

    mount '/git/' => builder {
        mount '/blame/' => \&Source::Tooling::Web::Git::blame;
        mount '/log/'   => \&Source::Tooling::Web::Git::log;
        mount '/show/'  => \&Source::Tooling::Web::Git::show;
        mount '/grep/'  => \&Source::Tooling::Web::Git::grep;
        mount '/' => sub {
            return [
                400, [], [
                    'Unsupported git command (',
                    $_[0]->{PATH_INFO},
                    ') supported commands include ( /git/show/:sha, /git/log/:path, /git/blame/:path )'
                ]
            ];
        };
    };

    mount '/' => sub { return [ 404, [], []] };
};


