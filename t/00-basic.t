#!/usr/bin/perl
# $Id: 00-basic.t 17 2012-08-29 06:16:11Z andrew $

use strict;
use warnings;

use Test::More tests => 3;

use blib;
use IO::File;

use_ok("LaTeX::Encode");

my $fh = IO::File->new($INC{"LaTeX/Encode.pm"}, "r");
my $content = join q{}, <$fh>;
undef $fh;

my ($module_version) = ($content =~ m{ \$VERSION\s*=\s*([\.\d]+) }x);
my ($doc_version)    = ($content =~ m{ describes \s+ version \s+ ([\.\d]+) }x);

like($module_version, qr{ \d+ \. \d+ }x, 'module version is sane');
is($module_version, $doc_version, 'module and POD version agree');
