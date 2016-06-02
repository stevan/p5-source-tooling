#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

BEGIN {
    use_ok('Source::Tooling::Git');
    use_ok('Source::Tooling::Perl');

    use_ok('Source::Tooling::Util::JSON');
    use_ok('Source::Tooling::Util::FileSystem');
    use_ok('Source::Tooling::Util::Transform');
}

done_testing;
