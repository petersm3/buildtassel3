#!/usr/bin/env perl

# Copyright (c) 2015 Oregon State University
# All Rights Reserved.
#
# Permission to use, copy, modify, and distribute this software and its
# documentation for educational, research and non-profit purposes, without
# fee, and without a written agreement is hereby granted, provided that
# the above copyright notice, this paragraph and the following three
# paragraphs appear in all copies.
#
# Permission to incorporate this software into commercial products may
# be obtained by contacting Oregon State University Office of Technology
# Transfer.
#
# This software program and documentation are copyrighted by Oregon State
# University. The software program and documentation are supplied "as is",
# without any accompanying services from Oregon State University. OSU does
# not warrant that the operation of the program will be uninterrupted or
# error-free. The end-user understands that the program was developed for
# research purposes and is advised not to rely exclusively on the program
# for any reason.
# 
# IN NO EVENT SHALL OREGON STATE UNIVERSITY BE LIABLE TO ANY PARTY FOR
# DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES,
# INCLUDING LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS
# DOCUMENTATION, EVEN IF OREGON STATE UNIVERSITYHAS BEEN ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE. OREGON STATE UNIVERSITY SPECIFICALLY
# DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE AND
# ANY STATUTORY WARRANTY OF NON-INFRINGEMENT. THE SOFTWARE PROVIDED
# HEREUNDER IS ON AN "AS IS" BASIS, AND OREGON STATE UNIVERSITY HAS NO
# OBLIGATIONS TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
# MODIFICATIONS.

##########################################################################
# Program : countbarcodes.pl 
# Author  : Matthew Peterson
# Email   : matthew@cgrb.oregonstate.edu
# Created : 20150222
# Modified: 20150304
# Purpose : From Illumina GBS lane(s) count the number of occurances of:
# - barcodes with restriction sites, any length, with Ns
# - barocdes with restriction sites, remove the barcode, truncate to 64
#   bases and then fitler out reads with Ns (aka TASSEL 3 processing)
# Produce a CSV with the resulting values to stdout
##########################################################################

use strict;
use warnings;
use Getopt::Long;
use File::Basename;
use Cwd 'abs_path';

# Arguments to be passed
my $fastq_input_dir;   # Single directory containing gzipped FASTQ file(s) to be converted
my $key_file;          # TASSEL key files containing barcodes (CSV or TSV format)
my $enzyme_file;       # Text file containing the enzyme used to cut, e.g., ApeKI or PstI-MspI
                       # See (TASSEL 3) TasselPipelineGBS.pdf page 8 for a list of enzymes
my $help;              # Print out usage()

GetOptions(
    'input|i=s' => \$fastq_input_dir,
    'key|k=s' => \$key_file,
    'enzyme|e=s' => \$enzyme_file,
    'help|h' => \$help,
);

usage() if (defined $help);

# Pre-flight
usage() if ( not defined $fastq_input_dir or not defined $key_file or not defined $enzyme_file);

if (! -r "$key_file") {
    print "\nERROR: CSV/TSV key file '$key_file' is not readable.\n";
    usage();
}

open KFH, '<', $key_file; 
my $key_file_header = <KFH>; 
close KFH;
if ( $key_file_header !~ /^Flowcell(,|\t)Lane(,|\t)Barcode(,|\t)Sample(,|\t)PlateName(,|\t)Row(,|\t)Column(,|\t)LibraryPrepID(,|\t)Comments/i) {
    print "\nERROR: CSV/TSV key file '$key_file'\n";
    print "       does not contain required header fileds (either CSV or TSV), e.g.,\n\n";
    print "       Flowcell,Lane,Barcode,Sample,PlateName,Row,Column,LibraryPrepID,Comments\n";
    usage();
}

if (! -r "$enzyme_file") {
    print "\nERROR: Enzyme file '$enzyme_file' is not readable.\n";
    usage();
}

# Enzyme or Enzyme Pair with Initial Cut Site Remnant(s)
# See (TASSEL 3) TasselPipelineGBS.pdf page 8 for a list of enzymes

my %enzymes = (
    'ApeKI' => 'CAGC|CTGC',
    'ApoI' => 'AATTC|AATTT',
    'BamHI' => 'GATCC',
    'EcoT22I' => 'TGCAT',
    'HinP1I' => 'CGC',
    'HpaII' => 'CGG',
    'MseI' => 'TAA',
    'MspI' => 'CCG',
    'NdeI' => 'TATG',
    'PasI' => 'CAGGG|CTGGG',
    'PstI' => 'TGCAG',
    'Sau3AI' => 'GATC',
    'SbfI' => 'TGCAGG',
    'AsiSI-MspI' => 'ATCGC',
    'BssHII-MspI' => 'CGCGC',
    'FseI-MspI' => 'CCGGCC',
    'PaeR7I-HhaI' => 'TCGAG',
    'PstI-ApeKI' => 'TGCAG',
    'PstI-EcoT22I' => 'TGCAG|TGCAT',
    'PstI-MspI' => 'TGCAG',
    'PstI-TaqI' => 'TGCAG',
    'SalI-MspI' => 'TCGAC',
    'SbfI-MspI' => 'TGCAGG',
    'HindIII-MspI' => 'AGCTT', # Not in TASSEL 3 list but is supported
    'SbfI-TaqI' => 'TGCAGG',   # 
    'PstI-SphI' => 'TGCAG',    # 
    'PstI-SbfI' => 'TGCAG'     # 
);

# If the enzyme provide is not in the set then quit out
open EFH, '<', $enzyme_file;
my $enzyme = <EFH>;
chomp($enzyme);
close EFH;
if (! exists($enzymes{"$enzyme"})) {
    print "\nERROR: Enzyme '$enzyme' in '$enzyme_file' is not a valid enzyme.\n";
    usage();
}

if (! -d "$fastq_input_dir") {
    print "\nERROR: Directory '$fastq_input_dir' does not exist.\n";
    usage();
}

# Check for number of gzipped FASTQ files
my @files = glob("$fastq_input_dir/*fastq*.gz");
my $total_fastq = scalar(@files); # Count of entries in array
if ($total_fastq == 0) {
    print "\nERROR: No gzipped FASTQ files (*.fastq*.gz) found in '$fastq_input_dir'\n";
    usage();
}

sub usage {
    print "\nUsage: $0 -i fastq_input_dir -k key_file -e enzyme_file > countbarcodes.csv\n\n";
    print "-i, --input\n";
    print "       Directory containing the gzipped FASTQ file(s) to be filtered\n";
    print "       TASSEL format filenames, e.g., code_FLOWCELL_s_LANE_fastq.txt.gz\n";
    print "       Important filename identifiers: _FLOWCELL_, _LANE_, fastq, gz\n";
    print "       FLOWCELL and LANE will match columns 1 and 2 in the TASSEL key file\n";
    print "-k, --key\n";
    print "       TASSEL key file (CSV or TSV format accepted)\n";
    print "-e, --enzyme\n";
    print "       Text file containing the enzyme used to cut the GBS lane\n";
    print "       See (TASSEL 3) TasselPipelineGBS.pdf page 8 for a list of enzymes\n";
    print "-h, --help\n";
    print "       This usage information.\n\n";
    exit(1);
}   

# Obtain a unique set of flowcell ids with lane numbers from the key file
open KFH, $key_file or die "Could not open file '$key_file'\n";
my %seen = ();
my @flowcells_lanes = ();
while (<KFH>) {
    chomp;
    my $line = $_;
    my $count = ($line =~ tr/,//);
    my @elements = ();
    if ($count > 6) {
        @elements = split (",", $line);
    } else {
        @elements = split ("\t", $line);
    }
    my $row_name = $elements[0] . '*' . $elements[1]; # Build wildcard match to be used below
    # First two elements of the header will be Flowcell and Lane; do not want this as part of output
    if ($row_name !~ /^flowcell/i) {
        push(@flowcells_lanes, $row_name) if ! $seen{$row_name}++;
    }
}
close KFH;

# Determine if there are one or two cut site remanats
my $dual_remants=0;
my $first_remant=$enzymes{$enzyme};
my $second_remant='';
if ($enzymes{$enzyme} =~ /\|/) {
    $dual_remants=1;
    my @remants = split(/\|/, $enzymes{$enzyme});
    $first_remant = $remants[0];
    $second_remant = $remants[1];
}

# Header mimcs key.csv and adds the counts for BarcodeCutSiteRemnants and TASSEL3Tags
print "Flowcell,Lane,Barcode,Sample,PlateName,Row,Column,LibraryPrepID,Comments,BarcodeCutSiteRemnants,TASSEL3Tags\n";
# ALL_BC66JVACXX_s_1_fastq.txt.gz
foreach my $flowcell_lane (@flowcells_lanes) {
    my %barcode_cut_site_remnant_count = ();
    my %barcode_tassel3_tag_count = ();
    my $flowcell_comma_lane = $flowcell_lane;
    $flowcell_comma_lane =~ tr/*/,/;
    open KFH, $key_file or die "Could not open file '$key_file'\n"; 
    # Itterate over key file for a single flowcell lane and initialize hashes
    # counting number of cut site remant and taseel3 tag counts to 0
    while (<KFH>) {
        chomp;
        my @row = split(/,/, $_);
        if("$row[0],$row[1]" eq "$flowcell_comma_lane") {
            $barcode_cut_site_remnant_count{"$row[2]"} = 0; 
            $barcode_tassel3_tag_count{"$row[2]"} = 0;
        }
    }
    close KFH;

    # Extract flowcell id and lane
    my @flowcell_lane = split /,/, $flowcell_comma_lane;
    my $flowcell=$flowcell_lane[0];
    my $lane=$flowcell_lane[1];
    # Should only be one match to this pattern, e.g., ALL_BC66JVACXX_s_1_fastq.txt.gz
    my @fastq_files = glob("${fastq_input_dir}/*_${flowcell}_*_${lane}_*fastq*gz");
    my $fastq_file = $fastq_files[0];
    open IFH, "/bin/gunzip -c $fastq_file | " or die "ERROR: Unable to open $fastq_file\n";
    while(my $line  = <IFH>) {
        # Header is first $line
        # Sequence
        my $fastq_sequence = <IFH>;
        # Third row '+'
        $line = <IFH>;
        # Quality
        $line = <IFH>;

        # Itterate over all of the barcodes for a single flowcell lane
        # Do not use regex comparisons; too slow for this volume of data
OUTER:  foreach my $barcode ( keys %barcode_cut_site_remnant_count ) {
            # Get length of barcode with cutsite, this will vary in size for each barcode
            my $barcode_cut_site_remnant_length = length("$barcode$first_remant");
            # Trim down the current sequence to the first set of bases representing the potential barcode with cut site remant
            my $fastq_sequence_barcode_cut_site_remnant = substr($fastq_sequence, 0, $barcode_cut_site_remnant_length);
            if($dual_remants) {
                # Comparison without regex
                if (("$fastq_sequence_barcode_cut_site_remnant" eq "$barcode$first_remant") ||
                    (("$fastq_sequence_barcode_cut_site_remnant" eq "$barcode$second_remant"))) {
                    $barcode_cut_site_remnant_count{$barcode}++;
                    # Remove barcode from string, leave remant
                    $fastq_sequence =~ s/^$barcode//;
                    # Trim to first 64 bases
                    my $fastq_sequence_64 = substr($fastq_sequence, 0, 64);
                    if ($fastq_sequence_64 !~ /N/) {
                        $barcode_tassel3_tag_count{$barcode}++;
                    }
                    last OUTER;
                }
            } else {
                # Single cut site remant
                # Comparison without regex
                if ($fastq_sequence_barcode_cut_site_remnant eq "$barcode$first_remant") {
                    $barcode_cut_site_remnant_count{$barcode}++;
                    # Remove barcode from string, leave remant
                    $fastq_sequence =~ s/^$barcode//;
                    # Trim to first 64 bases
                    my $fastq_sequence_64 = substr($fastq_sequence, 0, 64);
                    if ($fastq_sequence_64 !~ /N/) {
                       $barcode_tassel3_tag_count{$barcode}++; 
                    }
                    last OUTER;
                }
            }
        }
    }
    close IFH;

    # Print out results for current flowcell lane
    open KFH, $key_file or die "Could not open file '$key_file'\n";
    # Itterate over key file for a single flowcell lane and initialize hashes
    # counting number of cut site remant and taseel3 tag counts to 0
    while (<KFH>) {
        chomp;
        my @row = split(/,/, $_);
        my $row_flowcell = $row[0];
        my $row_lane = $row[1];
        my $row_barcode = $row[2];
        if("$row_flowcell,$row_lane" eq "$flowcell,$lane") {
            print "$_,$barcode_cut_site_remnant_count{$row_barcode},$barcode_tassel3_tag_count{$row_barcode}\n";
        }
    }
    close KFH;
}

# Copyright 2015 Oregon State University.
# All Rights Reserved. 
# 
# petersm3@cgrb.oregonstate.edu
