#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

is(system('perl', '-c', $_), 0, '... loaded ' . $_ . ' okay') foreach qw[
    bin/git/blame.pl
    bin/git/log.pl
    bin/git/show.pl

    bin/json/extract-key.pl
    bin/json/fmap.pl
    bin/json/group-by.pl
    bin/json/prune.pl
    bin/json/path-to-tree.pl

    bin/perl/collect-module-info.pl
];

done_testing;
