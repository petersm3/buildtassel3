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

# 20150305 matthew@cgrb.oregonstate.edu
# Original script 20140102
# Takes Aaron's barcode input and creates a
# valid key.csv for buildtassel3.bash, e.g.,
# 
# Example key file input (Flowcell,Lane, and LibraryPrepID are left unspecified)
# Flowcell,Lane,Barcode,Sample,PlateName,Row,Column,LibraryPrepID,Comments
# ,,GATT,my-sample-1,,A,1,,2
# 
# NOTE: Make sure that the newlines are correctly 
#       formatted for Linux. vim example:
#       %s/<ctrl v><ctrl m>/\r/g
# via cli:  tr '\015' '\n' < Keyfile.csv
###
IFS="
"

KEYFILE=$1
FLOWCELL=$2 # Include HiSeq A/B side
LANE=$3

usage () {
    echo ""
    echo "Usage: $0 KEYFILE FLOWCELL LANE"
    echo "e.g.,  $0 Keyfile_GBS001.csv BC35N2ACXX 6 > key.csv"
    echo ""
    exit 1
}

if [ -z "${KEYFILE}" ] || [ -z "${FLOWCELL}" ] || [ -z "${LANE}" ]; then
    usage
fi

if ! [[ -f ${KEYFILE} ]]; then
    echo ""
    echo "KEYFILE '${KEYFILE}' does not exist!"
    usage
fi

# Assuming at least 3 barcodes with a header
if [ `wc -l ${KEYFILE} | awk '{printf $1}'` -lt 4 ]; then
    echo "Key file contains less than 4 lines"
    echo "Please check and fix any newline encoding issues"
    echo "vim example: %s/<ctrl v><ctrl m>/\r/g"
    exit 1
fi

if ! [[ ${LANE} != *[!1-8]* ]]; then
    echo ""
    echo "LANE '${LANE}' needs to be a single digit, 1 to 8"
    usage
fi

dos2unix ${KEYFILE}

# Print out header, additional columns not included
#echo "Flowcell,Lane,Barcode,Sample,PlateName,Row,Column,Comments"
echo "Flowcell,Lane,Barcode,Sample,PlateName,Row,Column,LibraryPrepID,Comments"

for LINE in `cat ${KEYFILE} | grep -v "^Barcode"`; do
    # Caprice keeps changing this??
    BARCODE=`echo ${LINE} | awk -F, '{printf $3}'`
    SAMPLE=`echo ${LINE} | awk -F, '{printf $4}'`
    PLATENAME=`echo ${LINE} | awk -F, '{printf $5}'` 
    ROW=`echo ${LINE} | awk -F, '{printf $6}'`
    COLUMN=`echo ${LINE} | awk -F, '{printf $7}'`
    COMMENTS=`echo ${LINE} | awk -F, '{printf $9}'`

    # We don't use LibraryPrepID
    echo -n "${FLOWCELL},${LANE},${BARCODE},${SAMPLE},${PLATENAME},${ROW},${COLUMN},,"
    # You *must* have something in the last comment filed otherwise
    # TASSEL will generate an error similar to:
    #  Error with setupBarcodeFiles: java.lang.ArrayIndexOutOfBoundsException: 6
    #  Exception in thread "Thread-0" java.lang.NullPointerException
    if [ "${COMMENTS}" == '' ]; then
        echo "${SAMPLE}"
    else
        echo "${COMMENTS}"
    fi
done

