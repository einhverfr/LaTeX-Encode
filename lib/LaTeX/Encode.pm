#========================================================================
#
# LaTeX::Encode
#
# DESCRIPTION
#   Provides a function to encode text that contains characters
#   special to LaTeX.
#
# AUTHOR
#   Andrew Ford <a.ford@ford-mason.co.uk>
#
# COPYRIGHT
#   Copyright (C) 2007-2012 Andrew Ford.   All Rights Reserved.
#
#   This module is free software; you can redistribute it and/or
#   modify it under the same terms as Perl itself.
#
#   $Id: Encode.pm 32 2012-09-30 20:33:42Z andrew $
#========================================================================

package LaTeX::Encode;

use strict;
use warnings;

require 5.008_001;

use LaTeX::Encode::EncodingTable;

use Readonly;

use base qw(Exporter);

our $VERSION     = 0.08;

our @EXPORT      = qw(latex_encode);
our @EXPORT_OK   = qw(add_latex_encodings remove_latex_encodings reset_latex_encodings);
our %EXPORT_TAGS = ( all => [ qw( latex_encode 
                                  add_latex_encodings
                                  remove_latex_encodings
                                  reset_latex_encodings ) ] );

our @mappings_specified_on_import;

Readonly my $IMPORT_TAG_ADD    => 'add';
Readonly my $IMPORT_TAG_REMOVE => 'remove';


# Encode text with characters special to LaTeX

sub latex_encode {
    my $text = shift;
    my $options = ref $_[0] ? shift : { @_ };
    my $exceptions    = $options->{except};
    my $iquotes       = $options->{iquotes};
    my $packages_reqd = $options->{packages};
    my $unmatched     = $options->{unmatched};


    # If a list of exception characters was specified then we replace
    # those characters in the text string with something that is not
    # going to match the encoding regular expression.  The encoding we
    # use is a hex 01 byte followed by four hexadecimal digits

    if ($exceptions) {
        $exceptions =~ s{ \\ }{\\\\}gx;
        $text =~ s{ ([\x{01}$exceptions]) }
                  { sprintf("\x{01}%04x", ord($1)); }gxe;
    }

    # Deal with "intelligent quotes".  This can be done separately
    # from the rest of the encoding as the characters ` and ' are not
    # encoded.

    if ($iquotes) {

        # A single or double quote before a word character, preceded
        # by start of line, whitespace or punctuation gets converted
        # to "`" or "``" respectively.

        $text =~ s{ ( ^ | [\s\p{IsPunct}] )( ['"] ) (?= \w ) }
                  { $2 eq '"' ? "$1``" : "$1`" }mgxe;

        # A double quote preceded by a word or punctuation character
        # and followed by whitespace or end of line gets converted to
        # "''".  (Final single quotes are represented by themselves so
        # we don't need to worry about those.)

        $text =~ s{ (?<= [\w\p{IsPunct}] ) " (?= \s | $ ) }
                  { "''" }mgxe
    }


    # Replace any characters that need encoding

    $text =~ s{ ($encoded_char_re) }
              { $packages_reqd->{$provided_by{$1}} = 1
                    if ref $packages_reqd and exists $provided_by{$1};
                $latex_encoding{$1} }gsxe;

    $text =~ s{ ([\x{00}\x{02}-\x{09}\x{0b}\x{0c}\x{0e}-\x{1f}\x{007f}-\x{ffff}]) }
              { _replace_unencoded_char(ord($1), $unmatched) }gxse;


    # If the caller specified exceptions then we need to decode them

    if ($exceptions) {
        $text =~ s{ \x{01} ([0-9a-f]{4}) }{ chr(hex($1)) }gxe;
    }

    return $text;
}


sub _replace_unencoded_char {
    my ($charcode, $action) = @_;
    
    if (ref $action eq 'CODE') {
        return $action->($charcode);
    }
    elsif (($action || '') eq 'ignore') {
        return '';
    }
    else {
        return sprintf('\\%s{%04x}', $action || 'unmatched', $charcode);
    }
}


# Add encodings to the encoding table
# Return the changed encodings

sub add_latex_encodings {
    my (%new_encoding) = @_;
    my %old_encoding;
    my $changed;

    foreach my $key (keys %new_encoding) {
        if ((! exists $latex_encoding{$key}) or ($latex_encoding{$key} ne $new_encoding{$key})) {
            $old_encoding{$key} = $latex_encoding{$key} if defined wantarray and exists $latex_encoding{$key};
            $latex_encoding{$key} = $new_encoding{$key};
            $changed = 1;
        }
    }
    LaTeX::Encode::EncodingTable::_compile_encoding_regexp()
        if $changed;
    return unless defined wantarray;
    return %old_encoding;
}


# Remove encodings from the encoding table
# Return the removed encodings

sub remove_latex_encodings {
    my (@keys) = @_;
    my %removed_encoding;
    
    foreach my $key (@keys) {
        if (exists $latex_encoding{$key}) {
            $removed_encoding{$key} = delete $latex_encoding{$key};
        }
    }
    LaTeX::Encode::EncodingTable::_compile_encoding_regexp()
        if keys %removed_encoding;
    return unless defined wantarray;
    return %removed_encoding;
}


# Reset the encoding table

sub reset_latex_encodings {
    my ($class, $forget_import_specifiers) = @_;
    if ($class !~ /::/) {
        $forget_import_specifiers = $class;
    }

    delete $INC{'LaTeX/Encode/EncodingTable.pm'};
    undef &LaTeX::Encode::EncodingTable::_compile_encoding_regexp;
    require LaTeX::Encode::EncodingTable;

    if (! $forget_import_specifiers ) {
        foreach my $spec ( @mappings_specified_on_import ) {
            if ($spec->[0] eq $IMPORT_TAG_ADD) {
                add_latex_encodings(%{$spec->[1]});
            }
            elsif ($spec->[0] eq $IMPORT_TAG_REMOVE) {
                remove_latex_encodings(@{$spec->[1]});
            }
        }
    }
    
    return;
}


# Import function - picks out 'add' and 'remove' tags and adds or removes encodings
# appropriately

sub import {
    my ($self, @list) = @_;
    $DB::single = 1;
    my $i = 0;
    while ($i < @list) {
        if ($list[$i] eq $IMPORT_TAG_ADD) {
            my ($add, $to_add) = splice(@list, $i, 2);
            add_latex_encodings(%$to_add);
            push @mappings_specified_on_import, [ $IMPORT_TAG_ADD => $to_add ];
        }
        elsif ($list[$i] eq $IMPORT_TAG_REMOVE) {
            my ($remove, $to_remove) = splice(@list, $i, 2);
            remove_latex_encodings(@$to_remove);
            push @mappings_specified_on_import, [ $IMPORT_TAG_REMOVE => $to_remove ];
        }
        else {
            $i++;
        }
    }
    $self->export_to_level(1, $self, @list);
    return;
}

1;

__END__

=head1 NAME

LaTeX::Encode - encode characters for LaTeX formatting

=head1 SYNOPSIS

  use LaTeX::Encode ':all', add => { '@' => 'AT' }, remove => [ '$' ];

  $latex_string  = latex_encode($text, %options);

  %old_encodings = add_latex_encodings( chr(0x2002) => '\\hspace{.6em}' );
  %old_encodings = remove_latex_encodings( '<', '>' );

  reset_latex_encodings(1);

=head1 VERSION

This manual page describes version 0.08 of the C<LaTeX::Encode> module.


=head1 DESCRIPTION

This module provides a function to encode text that is to be formatted
with LaTeX.  It encodes characters that are special to LaTeX or that
are represented in LaTeX by LaTeX text-mode commands.

The special characters are: C<\> (command character), C<{> (open
group), C<}> (end group), C<&> (table column separator), C<#>
(parameter specifier), C<%> (comment character), C<_> (subscript),
C<^> (superscript), C<~> (non-breakable space), C<$> (mathematics mode).

Note that some of the LaTeX commands for characters are defined in the
LaTeX C<textcomp> package.  If your text includes such characters, you
will need to include the following lines in the preamble to your LaTeX
document.

    \usepackage[T1]{fontenc}
    \usepackage{textcomp}

The function is useful for encoding data that is interpolated into
LaTeX document templates, say with C<Template::Plugin::Latex>
(shameless plug!).

=head1 WARNING ABOUT UTF-8 DATA

Note that C<latex_encode()> will encode a UTF8 string (a string with the UTF8 flag set) or
a non-UTF8 string, which will normally be regarded as ISO-8859-1 (Latin 1) and will be
upgraded to UTF8.  The UTF8 flag indicates whether the contents of a string are regarded
as a sequence of Unicode characters or as a string of bytes.  Refer to the L<Unicode
Support in Perl|perlunicode>, L<Perl Unicode Introduction|perluniintro> and L<Perl Unicode
Tutorial|perlunitut> manual pages for more details.

If you are seeing spurious LaTeX commands in the output of C<latex_encode()> then it may
be that you are reading from a UTF-8 input or have data with UTF-8 characters in a literal
but the UTF8 flag is not being set correctly.  The fact that your programs are dealing
with UTF-8 characters on a byte-by-byte basis may not be apparent normally as the terminal
may make no distinction and happily display the byte sequence in the program's output as
the UTF-8 characters they represent, however in a Perl program that deals with individual
characters, what happens is that the individual bytes that make up multi-byte characters
are regarded as separate characters; if the strings are promoted to UTF8 strings then the
individual bytes are converted separately to UTF8.  This is termed double encoding.
C<latex_encode()> will then map the double-encoded characters.

If the input text is Western European text then what you are likely to see in the output
from C<latex_encode()> is spurious sequences of C<{\^A}> or C<{\~A}> followed by the
mapping of an apparently random character (or the right character if it is a symbol such
as the Sterling POUND sign, i.e. "£" will map to C<{\^A}\textsterling>); this is because
the initial byte of a two-byte UTF-8 character in the LATIN1 range will either be 0xC2 or
0xC3 and the next byte will always have the top two bits set to C<10> to indicate that it
is a continuation byte.


=head1 SUBROUTINES/METHODS

=over 4

=item C<latex_encode($text, %options)>

Encodes the specified text such that it is suitable for processing
with LaTeX.  The behaviour of the filter is modified by the options:

=over 4

=item C<except>

Lists the characters that should be excluded from encoding.  By
default no special characters are excluded, but it may be useful to
specify C<except = "\\{}"> to allow the input string to contain LaTeX
commands such as C<"this is \\textbf{bold} text"> (the doubled
backslashes in the strings represent Perl escapes, and will be
evaluated to single backslashes).

=item C<iquotes>

If true then single or double quotes around words will be changed to
LaTeX single or double quotes; double quotes around a phrase will be
converted to "``" and "''" and single quotes to "`" and "'".  This is
sometimes called "intelligent quotes"

=item C<packages>

If passed a reference to a hash C<latex_encode()> will update the hash with names of LaTeX
packages that are required for typesetting the encoded string.

=back


=item C<add_latex_encodings(%encodings)>

Adds a set of new or modified encodings.  Returns a hash of any encodings that were
modified.


=item C<remove_latex_encodings(@keys)>

Removes a set of encodings.  Returns a hash of the removed encodings.


=item C<reset_latex_encodings($forget_import_specifiers)>

Resets the LaTeX encodings to the state that they were when the module was loaded
(including any additions and removals specified on the 'use' statement), or to the
standard set of encodings if C<$forget_import_specifiers> is true.


=back


=head1 EXAMPLES

The following snippet shows how data from a database can be encoded
and inserted into a LaTeX table, the source of which is generated with
C<LaTeX::Table>.

    my $sth = $dbh->prepare('select col1, col2, col3 from table where $expr');
    $sth->execute;
    while (my $href = $sth->fetchrow_hashref) {
        my @row;
        foreach my $col (qw(col1 col2 col3)) {
            push(@row, latex_encode($href->{$col}));
        }
        push @data, \@row;
    }

    my $headings = [ [ 'Col1', 'Col2', 'Col3' ] ];

    my $table = LaTeX::Table->new( { caption => 'My caption',
                                     label   => 'table:caption',
                                     type    => 'xtab',
                                     header  => $header,
                                     data    => \@data } );

    my $table_text = $table->generate_string;    

Now C<$table_text> can be interpolated into a LaTeX document template.


=head1 DIAGNOSTICS

None.  You could probably break the C<latex_encode> function by
passing it an array reference as the options, but there are no checks
for that.

=head1 CONFIGURATION AND ENVIRONMENT

Not applicable.


=head1 DEPENDENCIES

The C<HTML::Entities> and C<Pod::LaTeX> modules were used for building
the encoding table in C<LaTeX::Encode::EncodingTable>, but this is not
rebuilt at installation time.  The C<LaTeX::Driver> module is used for
formatting the character encodings reference document.

=head1 INCOMPATIBILITIES

None known.

=head1 BUGS AND LIMITATIONS

Not all LaTeX special characters are included in the encoding tables
(more may be added when I track down the definitions).



=head1 AUTHOR

Andrew Ford E<lt>a.ford@ford-mason.co.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2007-2012 Andrew Ford.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

This software is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=head1 SEE ALSO

L<Template::Plugin::Latex>

L<Unicode Support in Perl|perlunicode>

L<Perl Unicode Introduction|perluniintro>

L<Perl Unicode Tutorial|perlunitut>

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
