#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

BEGIN {
    use_ok('Code::Tooling::Git');
    use_ok('Code::Tooling::Perl');

    use_ok('Code::Tooling::Util::JSON');
    use_ok('Code::Tooling::Util::FileSystem');
}

done_testing;
