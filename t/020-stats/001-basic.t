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
        [ map { $_->name } $f->packages ],
        '... got the packages we expected'
    );

    is_deeply(
        [ 1, 1, 1 ],
        [ map { $_->line_count } $f->packages ],
        '... got the package line counts we expected'
    );
};

subtest '... basic sub test' => sub {

    my $src = q[
            sub foo { $_[0] * 10 }
            sub bar {
                my $x = 0 .. 100;
                $x += 2;
                return $x;
            }
            package Foo {
                sub baz {
                    $_[0]->{wtf}
                }
            }
        1;
    ];

    my $f = Source::Tooling::Perl::Stats::File->new( \$src );

    is_deeply(
        [qw[ foo bar ]],
        [ map { $_->name } $f->subs ],
        '... got the subs we expected'
    );

    is_deeply(
        [ 1, 5 ],
        [ map { $_->line_count } $f->subs ],
        '... got the sub line counts we expected'
    );

    subtest '... test the Foo package' => sub {
        my ($Foo) = $f->packages;

        is($Foo->name, 'Foo', '... got the expected name');
        is($Foo->line_count, 6, '... got the expected line count');

        is_deeply(
            [qw[ baz ]],
            [ map { $_->name } $Foo->subs ],
            '... got the subs we expected'
        );

        is_deeply(
            [ 3 ],
            [ map { $_->line_count } $Foo->subs ],
            '... got the sub line counts we expected'
        );
    };
};

done_testing;
