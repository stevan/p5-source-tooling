#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

BEGIN {
    use_ok('Source::Tooling::Perl::Stats::File');
    use_ok('Source::Tooling::Perl::Stats::Package');
    use_ok('Source::Tooling::Perl::Stats::Sub');
    use_ok('Source::Tooling::Perl::Stats::Var');
}

subtest '... basic package test' => sub {

    my $src = q[
        package Foo;

        package Bar;

        package Foo::Bar;

        1;
    ];

    my $f = Source::Tooling::Perl::Stats::File->new( \$src );

    is_deeply(
        [qw[ Foo Bar Foo::Bar ]],
        [ map { $_->namespace } $f->packages ],
        '... got the packages we expected'
    );

};

subtest '... basic sub test' => sub {

    my $src = q[
            sub foo { $_[0] * 10 }
            sub bar { 0 .. 100   }
            package Foo {
                sub baz { $_[0]->{wtf} }
            }
        1;
    ];

    my $f = Source::Tooling::Perl::Stats::File->new( \$src );

    is_deeply(
        [qw[ foo bar baz ]],
        [ map { $_->name } $f->subs ],
        '... got the subs we expected'
    );
};

done_testing;
