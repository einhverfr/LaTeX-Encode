# $Id: Makefile.PL 30 2012-09-25 20:24:40Z andrew $

use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'LaTeX::Encode',
    AUTHOR              => 'Andrew Ford <a.ford@ford-mason.co.uk>',
    VERSION_FROM        => 'lib/LaTeX/Encode.pm',
    ABSTRACT_FROM       => 'lib/LaTeX/Encode.pm',
    PL_FILES            => {},
    EXE_FILES           => [ 'scripts/latex-encode' ],
    PREREQ_PM => {
        'Getopt::Long'      => 0,
        'HTML::Entities'    => 0,
        'Pod::LaTeX'        => 0,
        'Pod::Usage'        => 0,
        'Readonly'          => 0,
        'Test::More'        => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'LaTeX-Encode-*' },
);

no warnings 'redefine';

sub MY::postamble {
    return q{
lib/LaTeX/Encode/EncodingTable.pm: scripts/build-encoding-table
	 scripts/build-encoding-table >lib/LaTeX/Encode/EncodingTable.pm
};
}
