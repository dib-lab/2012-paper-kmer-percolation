eval '(exit $?0)' && eval 'exec perl -x -S $0 ${1+"$@"}' &&
eval 'exec perl -x -S  $0 $argv:q'
if 0;
#!/usr/local/bin/perl -w

# (C) John Collins, collins at phys.psu.edu, 2002-2003
# License: GPL
##
##    This program is free software; you can redistribute it and/or modify
##    it under the terms of the GNU General Public License as published by
##    the Free Software Foundation; either version 2 of the License, or
##    (at your option) any later version.
##
##    This program is distributed in the hope that it will be useful,
##    but WITHOUT ANY WARRANTY; without even the implied warranty of
##    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##    GNU General Public License for more details.
##
##    You should have received a copy of the GNU General Public License
##    along with this program; if not, write to the Free Software
##    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307
#
#  2 Jun 2004 JCC Obfuscate e-mail address
# 23 Nov 2003 JCC Public relase.  V. 1.00
#  8 Apr 2003 JCC Deal with list of citations in aux file created by citesort.
#  5 Apr 2003 JCC Try to fix extra spaces in reordered refs.
# 19 Jan 2003 JCC Bug (incorrect test for existing citeseq) found, corrected.
# 18 Jan 2003 JCC Looking for bug
# 16 Dec 2002 JCC Use 2 argument invocation of open
#                 Bug fixes
#                 Clean-up algorithms
# 15 Dec 2002 JCC Small corrections
# 14 Dec 2002 JCC Original version.

use File::Basename;

# Version details:
$my_name = "orderrefs";
$version_num = '1.00';
$version_details = "$my_name $version_num, John Collins, 2 June 2004";

# Configuration variables:
$bibname = "thebibliography"; # name of environment for thebibliography
$aux = "";  # Use default aux file

$need_usage = 0;
while ($_ = $ARGV[0]) {
    if ( ! /^-/ ) {
        # cmd line argument is not option
        last;
    }
    shift;
    if ( /^--help$/ || /^-h$/ ) {
        &print_help; 
        exit 0;
    }
    elsif ( /^--version$/ || /^-v$/ ) {
        print "$version_details\n";
        exit 0;
    }
    elsif ( /^-b$/ ) {
       if ( $ARGV[0] eq '' ) {
          &die_help( "$my_name: No bibliography name after -b option");
       }
       $bibname = shift;
    }
    elsif ( /^--bibname=(.*)$/ ) {
	$bibname = $1;
    }
    elsif ( /^-a$/ ) {
       if ( $ARGV[0] eq '' ) {
          &die_help( "$my_name: No auxfile name after -b option");
       }
       $aux = shift;
    }
    elsif ( /^--auxfile=(.*)$/ ) {
	$aux = $1;
    }
    else {
        warn "Undefined option \"$_\"\n";
        $need_usage = 1;
    }
}



if ( $#ARGV <= -1 ) {
    &print_usage;
    exit 1;
}
if ($need_usage) { 
    &print_usage; 
}


$given_name = $ARGV[0];
# Apply teTeX rules for finding TeX file.
&get_names( $given_name, $tex, $base, $path);
$texbak = "$tex.bak";
# Except that I assume the aux file is in same directory as tex file:
if ( $aux eq "") {$aux = "$path$base.aux";}
$tmp = "$path$base-$my_name-$$.tex";
#die "BASE=\"$base\", PATH=\"$path\", EXT=\"$ext\", \n",
#    "TEX=\"$tex\", TEXBAK=\"$texbak\", AUX=\"$aux\", TMP=\"$tmp\"\n";


if ( !-e $tex ) {
    die "TeX file does not exist. ",
        "Both of \"$tex\" and \"$tex.tex\" were tried.\n";
}
if ( !-e $aux ) {
    die "Aux file \"$aux\" does not exist\n";
}


# Database of citations:
@cite = ();           # Keys in order of citation.
@bibitem_exists = (); # Whether there is a bibitem for this citation
%citeseq = ();        # Map key to position in @cite

# Database of bibitems
@bib = ();     # List of bibitems, in order of appearence in file
               # Each item is a ref to a hash of form
               # { data => array of lines of file,
               #   label => ...,   # Undefine if no label
               #   key => ...,     # Undefine if no key
               #   cited => 0|1,   # whether cited
               #   seq => 0|1,     # whether automatic default label
               # }
%bibseq = ();  # Maps keys to position in @bib.

read_aux($aux)
    or die "Problem reading aux file \"$aux\"\n";
new_tex($tex, $tmp)
    or die "Problem making new tex file \"$tex\"\n";
if (&is_biblio_ordered) {
    print "Bibitems are correctly ordered\n";
    unlink $tmp;
}
else {
    rename($tex, $texbak)
     or die "Cannot create backup tex file \"$texbak\"\n";
    rename($tmp, $tex)
     or die "Cannot make new tex file \"$tex\" from temporary file \"$tmp\"\n";
    print "Reordered bibitems. Original tex file is now \"$texbak\"\n";
}


#====================================================
sub read_aux{
# Set up database of citations from aux file.
# Information is given by lines of form
#  \citation{key}
# in order of citation.
# $_[0] is name of aux file
# Return results in @cite, %citeseq.
    my $aux_file = $_[0];
    local *AUX;
    open( AUX, "<$aux_file" ) 
        or die "Cannot read \"$aux_file\"\n";
AUXLINE:
    while (<AUX>) {
        if ( /^[\s]*\\citation[\s]*\{([^\}]*)\}/ ) {
            my $thiskey_string = $+;
            # Note: if the source document uses the citesort package,
            #       then the argument of \\citation can contain a
            #       comma-separated list of keys.
            foreach my $thiskey (split /,/, $thiskey_string) {
               if ( ! defined $citeseq{$thiskey} ) {
                   push @cite, $thiskey;
                   $bibitem_exists[$#cite] = 0;
                   $citeseq{$thiskey} = $#cite;
#		   warn "New cite: $#cite $thiskey\n";
               }
               else {
#	   	warn "Already defined cite: $thiskey, index $citeseq{$thiskey}\n";
	       }
           } # end $thiskey 
	} # end processing of \citation{...}
    } # end AUXLINE
    close AUX;
    return 1;  # Success
}

#====================================================
sub show_aux{
# Display citation database, remembering to convert 0-based index into @cite
# into 1-based index seen by user.
    for (my $i = 0; $i <= $#cite; $i++) {
        my $user_seq = $i + 1;
        print "[$user_seq] = $cite[$i]\n";
    }
    foreach my $key ( sort( keys(%citeseq) ) ) {
        my $user_seq = $citeseq{$key} + 1;
        print "$key = [$user_seq]\n";
    }
}

#====================================================
sub new_tex{
# $_[0] = name of input TeX file
# $_[1] = name of output TeX file
# Given database of citations, copy input to output, with reordering of 
# bibitems in the following order:
# 1. Numbered cited bibitems, i.e, cited bibitems which don't have the
#       optional label, in order of first citation.
# 2. All other bibitems in order of appearance in original bibliography.
# Return 1 on success, 0 or die on failure.
    my $in_file = $_[0];
    my $out_file = $_[1];

    local *IN;
    local *OUT;
    open( IN, "<$in_file" ) 
        or die "Cannot read \"$in_file\"\n";
    open( OUT, ">$out_file" ) 
        or die "Cannot write \"$out_file\"\n";
    # Use state machine for parsing
    # $state == 1:  before thebibliography environment
    #               (Actual name of environment is in $bibname)
    #           2:  in thebibliography, before first bibitem
    #           3:  in thebibliography, reading bibitems
    #           4:  after thebibliography
    my $state = 1;
TEXLINE:
    while (<IN>) {
        my $line = $_;
        if ($state == 1) {
	    if ( /^[\s]*\\begin[\s]*\{$bibname\}/ ) {
                # Have found \begin{thebibliography} (or c.)
                $state = 2;   # In thebibliography, before a bibitem.
	    }
	}
        elsif ( ($state == 2) || ($state == 3) ) {
	    if ( /^[\s]*\\bibitem[\s]*(\[|\{)/ ) {
                # Have \bibitem[... or \bibitem{...
                $state = 3;
                push @bib, { data=>[], cited=>0, seq=>0 };
                # And leave label and key entries undefined
	    }
            elsif ( /^[\s]*\\end[\s]*\{$bibname\}/ ) {
                # Have found \end{thebibliography} (or c.)
                $state = 4;   # After thebibliography
                @orderedbib = ();  # List of bibitems in correct order
                &parse_biblio;
#                &show_biblio;
                for (my $i = 0; $i <= $#bib; $i++) {
                    &print_array(OUT, @{ $orderedbib[$i]->{data} });
#THIS GIVES EXTRA SPACES:
#                    print OUT "@{ $orderedbib[$i]->{data} }";
                }
	    }
	}
        if ($state == 3) {
            push @{$bib[$#bib]->{data}}, $line;
        }
        else {
            print OUT $line;
        }
    } #end TEXLINE
    close IN;
    close OUT;
    if ($state != 4) {
	warn "Could not find environment \"$bibname\" in file \"$in_file\"\n";
        return 0;  # Failure
    }
    return 1;  # Success
}

#====================================================
sub is_biblio_ordered {
    for (my $i = 0; $i <= $#bib; $i++) {
	if ( $orderedbib[$i] != $bib[$i] ){
            return 0;
	}
    }
    return 1;
}

#====================================================
sub parse_biblio {
# 1. Parse the bibitems, and complete the referencing in the databases:
BIBITEMPARSE:
    for (my $i = 0; $i <= $#bib; $i++ ) {
        my $thisbibitem = $bib[$i];
        my $firstline = ${$thisbibitem->{data}}[0];
        if ( $firstline =~ /^[\s]*\\bibitem[\s]*\{([^\}]*)\}/ ) {
            # \\bibitem{key}
            undef $thisbibitem->{label};
            $thisbibitem->{key} = $1;
        }
        elsif ( $firstline 
                =~ /^[\s]*\\bibitem[\s]*\[([^\]]*)\]\{([^\}]*)\}/ ) 
        {
            # \\bibitem[label]{key}
            $thisbibitem->{label} = $1;
            $thisbibitem->{key} = $2;
        }
        else {
            warn "Bad bibitem:\n   $firstline";
            undef $thisbibitem->{label};
            undef $thisbibitem->{key};
            next BIBITEMPARSE;
        }
        $thiskey = $thisbibitem->{key};
        if ( defined $bibseq{$thiskey} ) {
            warn "Multiply defined key \"$thiskey\"\n";
            next BIBITEMPARSE;
        }
        $bibseq{$thiskey} = $i;  
        if ( defined $citeseq{$thiskey} ) {
            $bibitem_exists[$citeseq{$thiskey}] = 1;
            $thisbibitem->{cited} = 1;
        }
        else {
            warn "Uncited bibitem, key = \"$thiskey\"\n";
        }
    } # end BIBITEMPARSE

#2. Check for undefined citations:
CITATION:
    for (my $i = 0; $i <= $#cite; $i++) {
        if ( ! $bibitem_exists[$i] ) {
            warn "Undefined citation \"$cite[$i]\"\n";
	}
    }

#3. Create ordered list of bibitems:
    @orderedbib = ();
    # First the cited bibitems which use the default numerical label
    #   (i.e,. that have no user-defined label)
    for (my $i = 0; $i <= $#cite; $i++ ) {
        if ( $bibitem_exists[$i] ) {
            my $bibitem = $bib[ $bibseq{$cite[$i]} ];
            if ( !defined( $bibitem->{label} ) ) {
                push @orderedbib, $bibitem;
                $bibitem->{seq} = 1;
            }
        }
    }
    # Next the remaining bibitems
    for (my $i = 0; $i <= $#bib; $i++ ) {
        if ( ! $bib[$i]->{seq}  ) {
            push @orderedbib, $bib[$i];
        }
    }
}

#====================================================
sub show_biblio {
    for (my $i = 0; $i <= $#bib; $i++ ) {
        my $thisbibitem = $bib[$i];
        my $user_seq = $i+1;
        print "BIBITEM $user_seq:  ";
        if ( defined( $thisbibitem->{label} ) ) {
	    print "label=\"$thisbibitem->{label}\", ";
        }
	else {
            print "no label, ";
	}
        if ( defined( $thisbibitem->{key} ) ) {
	    print "key=\"$thisbibitem->{key}\", ";
        }
	else {
            print "no key, ";
	}
        print "cited=$thisbibitem->{cited}\n";
#        warn "@{$thisbibitem->{data}}";
#        warn "\n";
    }
    print "\nORDERED bibitems:\n";
    for (my $i = 0; $i <= $#bib; $i++) {
        &print_array(STDOUT, @{ $orderedbib[$i]->{data} });
    }
}

#====================================================
#====================================================
sub print_help {
   print <<HELP;
Usage: 

    $my_name [options] file

Makes new version of LaTeX file, with bibitems ordered in order of
citation, as determined from the aux file.  Uncited bibitems and bibitems
with an explicit label are kept in the order they are in the original
file, after the list of ordered bibitems.  A backup copy is made of the
original LaTeX file, in a file with the same name as the LaTeX file, but
with .bak added.  The default extension for the LaTeX file is .tex.

You should run latex on the LaTeX file before running $my_name, in
order to ensure that the aux file exists and is up-to-date.

The bibitems are identified as being in an environment with the name 
thebibliography.  It is assumed that the \\begin{thebibliography}, the
\\end{thebibliography}, and the \\bibitem commands all start a line
preceeded at most by white space.

Options:
    -b name            synonym for --bibname=name
    --bibname=name     specifies name of LaTeX environment containing
                       the bibliography.  (Default: "thebibliography".)
    -a file            synonym for --auxfile=file
    --auxfile=file     specifies name of .aux file.  (Default is constructed 
                       from name of LaTeX file with extension .aux.) 
    -h or --help       displays this message
    -v or --version    gives version number
HELP
}

#====================================================
sub print_usage {
    print <<USAGE;
$version_details
Usage: 
      $my_name base
orders references in tex file
      $my_name --help
for detailed help
USAGE
}

#====================================================

sub get_names {
    # Apply teTeX rules for finding name of tex and aux file
    #$_[0] = given name
    # Return $_[1] = name of tex file
    #        $_[2] = base name for aux files
    #        $_[3] = path
    my $given_name = $_[0];
    my $tex;
    if ( -e "$given_name.tex" ) {
    $tex = "$given_name.tex";
    }
    else {
        $tex = "$given_name";
    }
    my ($base, $path, $ext) = fileparse ($tex, '\.[^\.]*');
    if ( $path eq ".\\" ) { 
        $path = "";
    }
    $_[1] = $tex;
    $_[2] = $base;
    $_[3] = $path;
}

#====================================================

sub die_help
# Die giving diagnostic from arguments and how to get help.
{
    die "\n@_\nUse\n    $my_name --help\nto get usage information\n";
}
#====================================================

sub print_array
# Usage print_array(stream, items)
{
    my $FILE = shift;
    foreach (@_) {print $FILE $_;};
}

#====================================================

