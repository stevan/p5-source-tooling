#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;

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

        package Bar {
            our $VERSION = '0.01';
        };

        package Foo::Bar {

        };

        1;
    ];

    my $f = Source::Tooling::Perl::Stats::File->new( \$src );

    #diag $f->ppi_dump;

    is_deeply(
        [qw[ Foo Bar Foo::Bar ]],
        [ map { $_->name } $f->packages ],
        '... got the packages we expected'
    );

    is_deeply(
        [ undef, q['0.01'], undef ],
        [ map { $_->version ? $_->version->value : undef } $f->packages ],
        '... got the package version we expected'
    );

    is_deeply(
        [ 1, 3, 3 ],
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
            sub baz;
            package Foo {
                sub baz {
                    $_[0]->{wtf}
                }
            }
        1;
    ];

    my $f = Source::Tooling::Perl::Stats::File->new( \$src );

    is_deeply(
        [qw[ foo bar baz ]],
        [ map { $_->name } $f->subs ],
        '... got the subs we expected'
    );

    is_deeply(
        [ 1, 5, 1 ],
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

subtest '... basic variable test' => sub {

    my $src = q[
            our $TEST;
            our ($TEST1, @TEST2);
            our $FOO = 10;
            our ($BAR, @BAZ) = (20, 30);
            our $GORCH = $TEST;
            package Foo {
                our $BAR = 20;
                $Foo::BAZ = 30; # implicit declaration
                $main::FOO = 20;
            }
        1;
    ];

    my $f = Source::Tooling::Perl::Stats::File->new( \$src );

    #diag $f->ppi_dump;

    #warn Dumper([ map $_->symbol, $f->vars ]);

    is_deeply(
        [qw[ $TEST $TEST1 @TEST2 $FOO $BAR @BAZ $GORCH ]],
        [ map { $_->symbol } $f->vars ],
        '... got the vars we expected'
    );

    is_deeply(
        [ undef, undef, undef, '10', '20', '30', '$TEST' ],
        [ map { $_->value } $f->vars ],
        '... got the var values we expected'
    );

    subtest '... test the Foo package' => sub {
        my ($Foo) = $f->packages;

        is($Foo->name, 'Foo', '... got the expected name');
        is($Foo->line_count, 6, '... got the expected line count');

        is_deeply(
            [qw[ $BAR $Foo::BAZ ]],
            [ map { $_->symbol } $Foo->vars ],
            '... got the vars we expected'
        );

        is_deeply(
            [ '20', '30' ],
            [ map { $_->value } $Foo->vars ],
            '... got the var values we expected'
        );
    };

};


done_testing;
