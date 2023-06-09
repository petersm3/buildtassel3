#!/usr/bin/env bash

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

# 20151013 petersm3
# Wrapper script to generate passfail.csv stats for GBS run
# Calls: countreads.bash, countbarcodes.pl, and passfail.pl

RDIR=$1
STATS_DIR=/local/cluster/hts/gbs/scripts/stats
COUNTREADS_CMD=${STATS_DIR}/countreads.bash
COUNTBARCODES_CMD=${STATS_DIR}/countbarcodes.pl
PASSFAIL_CMD=${STATS_DIR}/passfail.pl

if [ "$1" == '' ]; then
    echo "Need to provide TASEL UNEAK GBS directory as input argument, e.g.,"
    echo "$0 /hts2/gbs/GBS0060-150717_SN609_0375_AC7EDWACXX_1197-L1/0001-default-uneak"
    exit 1
fi

# Make sure enzyme.txt file exists; have a habbit of running this script before UNEAK has been started
if [ ! -f "${RDIR}/support/enzyme.txt" ]; then
    echo "ERROR: ${RDIR}/support/enzyme.txt does not exist!"
    exit 1
fi

# NOTE: Needs error checking to check for properly formatted key file, FASTQ file, and enzyme.txt

# Check to see if the user did not edit key.csv for their run and left the default ABC12AAXX
if [ `grep 'ABC12AAXX' ${RDIR}/key.csv | wc -l` -ne 0 ]; then
    echo "ERROR: It looks like ${RDIR}/key.csv is not a 'real' key file."
    echo "       For example the sample flow cell 'ABC12AAXX' is in your key file."
    echo ""
    echo "       Make sure a 'real' key file has already been setup for the run already!"
    echo "       (In addition ${RDIR}/support/enzyme.txt needs to be correctly defined!"
    exit 1
fi

# Setup stats directory
mkdir -p ${RDIR}/stats/original

# Count Reads
${COUNTREADS_CMD} ${RDIR}/Illumina > ${RDIR}/stats/original/countreads.csv

# Count Barcodes (requires a preformatted key file)
${COUNTBARCODES_CMD} -i ${RDIR}/Illumina -k ${RDIR}/key.csv -e ${RDIR}/support/enzyme.txt > ${RDIR}/stats/original/countbarcodes.csv

# Generate pass/fail metrics
${PASSFAIL_CMD} -b ${RDIR}/stats/original/countbarcodes.csv -r ${RDIR}/stats/original/countreads.csv > ${RDIR}/stats/original/passfail.csv
