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
# Program : passfail.pl 
# Author  : Matthew Peterson
# Email   : matthew@cgrb.oregonstate.edu
# Created : 20150309
# Modified: 20150309
# Purpose : Annotate the results of countbarcodes.pl CSV output with:
# - (Number of 'good barcoded TASSEL 3 reads' per barcoded sample) /
#   ((Total reads per lane) / (Number of Samples per lane))
# - pass/fail, e.g., Cornell's definition of "less than 10% of the mean 
#   reads per sample coming from the lane on which they were sequenced"
##########################################################################

use strict;
use warnings;
use Getopt::Long;
use File::Basename;
use Cwd 'abs_path';

# Arguments to be passed
my $countbarcodes_file;  # countbarcodes.csv produced by countbarcodes.pl
my $countreads_file;     # countreads.csv containing: "Flowcell,Lane,Reads" per flowcell lane
my $percentage=10;       # Percentage to determine if a sample passes or failes, Cornell default of 10%
my $help;                # Print out usage()

GetOptions(
    'barcodes|b=s' => \$countbarcodes_file,
    'reads|r=s' => \$countreads_file,
    'percentage|p=i' => \$percentage,
    'help|h' => \$help,
);

usage() if (defined $help);
# Pre-flight
usage() if ( not defined $countbarcodes_file or not defined $countreads_file);

if (! -r "$countbarcodes_file") {
    print "\nERROR: countbarcodes.csv file '$countbarcodes_file' is not readable.\n";
    usage();
}

open BFH, '<', $countbarcodes_file; 
my $countbarcodes_file_header = <BFH>; 
close BFH;
if ( $countbarcodes_file_header !~ /^Flowcell(,|\t)Lane(,|\t)Barcode(,|\t)Sample(,|\t)PlateName(,|\t)Row(,|\t)Column(,|\t)LibraryPrepID(,|\t)Comments(,|\t)BarcodeCutSiteRemnants(,|\t)TASSEL3Tags/i) {
    print "\nERROR: countbarcodes.csv file '$countbarcodes_file'\n";
    print "       does not contain required header fileds, e.g.,\n\n";
    print "       Flowcell,Lane,Barcode,Sample,PlateName,Row,Column,LibraryPrepID,Comments,BarcodeCutSiteRemnants,TASSEL3Tags\n";
    usage();
}

if (! -r "$countreads_file") {
    print "\nERROR: countreads.csv file '$countreads_file' is not readable.\n";
    usage();
}

open RFH, '<', $countreads_file;
my $countreads_file_header = <RFH>;
close RFH;
if ( $countreads_file_header !~ /^Flowcell(,|\t)Lane(,|\t)Reads/i) {
    print "\nERROR: countreads.csv file '$countreads_file'\n";
    print "       does not contain required header fileds, e.g.,\n\n";
    print "       Flowcell,Lane,Reads\n";
    usage();
}

sub usage {
    print "\nUsage: $0 -b countbarcodes_file -r countreads_file [-p percentage]\n\n";
    print "-b, --barcodes\n";
    print "       countbarcodes.csv produced by countbarcodes.pl\n";
    print "-r, --reads\n";
    print "       countreads.csv (reads per flowcell lane) in the format:\n";
    print "       Flowcell,Lane,Reads\n";
    print "-p, --percentage\n";
    print "       Optional percentage cutoff (default is 10%) to determine if a\n";
    print "       sample is defined as either 'pass' or 'fail' per:\n";
    print "       (Number of 'good barcoded TASSEL 3 reads' per barcoded sample)\n";
    print "       ((Total reads per lane) / (Number of Samples per lane))\n";
    print "-h, --help\n";
    print "       This usage information.\n\n";
    exit(1);
}   

# Obtain a unique set of flowcell ids with lane numbers and read counts
my %flowcell_lane_reads = ();  # Store number of total Illumina lanes per flowcell lane
open RFH, $countreads_file or die "Could not open file '$countreads_file'\n";
$countreads_file_header = <RFH>;
while (<RFH>) {
    chomp;
    my @row = split(/,/, $_);
    $flowcell_lane_reads{"$row[0],$row[1]"} = $row[2];
}
close RFH;

# Obtain count of samples per unique flowcell lane
my %flowcell_lane_samples = ();
open BFH, $countbarcodes_file or die "Could not open file '$countbarcodes_file'\n";
$countbarcodes_file_header = <BFH>;
while (<BFH>) {
    chomp;
    my @row = split(/,/, $_);
    # Increment each occurance of a Flowcell,Lane entry
    $flowcell_lane_samples{"$row[0],$row[1]"}++;
}
close RFH;

# Header mimcs key.csv and adds the columns PassFailPercentage and PassFail
print "Flowcell,Lane,Barcode,Sample,PlateName,Row,Column,LibraryPrepID,Comments,BarcodeCutSiteRemnants,TASSEL3Tags,PassFailPercentage,PassFail\n";

# Print out results for current flowcell lane
open BFH, $countbarcodes_file or die "Could not open file '$countbarcodes_file'\n";
$countbarcodes_file_header = <BFH>;
# Itterate over key file for a single flowcell lane and initialize hashes
while (<BFH>) {
    chomp;
    my @row = split(/,/, $_);
    my $row_flowcell = $row[0];
    my $row_lane = $row[1];
    my $row_barcode = $row[2];
    my $row_tassel3tags = $row[10];

    # (Number of 'good barcoded TASSEL 3 reads' per barcoded sample) /
    # ((Total reads per lane) / (Number of Samples per lane))
    my $total_flowcell_lane_samples = $flowcell_lane_samples{"$row_flowcell,$row_lane"};;
    my $total_reads = $flowcell_lane_reads {"$row_flowcell,$row_lane"};
    my $pass_fail_percentage = sprintf("%.3f",  ( ( ($row_tassel3tags) / ($total_reads / $total_flowcell_lane_samples)) * 100));
    my $pass_fail = 'pass';
    if ($pass_fail_percentage < $percentage) {
        $pass_fail = 'fail';
    }
    print "$_,$pass_fail_percentage,$pass_fail\n";
}
close BFH;

# Copyright 2015 Oregon State University.
# All Rights Reserved. 
# 
# petersm3@cgrb.oregonstate.edu
