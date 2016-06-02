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

done_testing;
