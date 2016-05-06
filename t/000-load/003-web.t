#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use Plack::Util;

is(
    exception { Plack::Util::load_psgi('./root/app.psgi') },
    undef,
    '... loaded the app.psgi successfully'
);

done_testing;
