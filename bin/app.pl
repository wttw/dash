#!/usr/bin/env perl
BEGIN { $ENV{DBI_PUREPERL} = 2 }
use FindBin;
use lib "$FindBin::Bin/../lib";
use Dancer;
use dash;
dance;
