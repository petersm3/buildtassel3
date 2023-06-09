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

# 20150721 petersm3
# Count number of reads per FASTQ file
# Manually redirect output to a ${1}/../stats/original/countreads.csv
# countreads.csv is used by passfail.bash
# Supports multiple FASTQ files per Illumina directory
if [ "$1" == '' ]; then
    echo "Need to provide Illumina directory as input argument, e.g.,"
    echo "$0 /hts2/gbs/GBS0060-150717_SN609_0375_AC7EDWACXX_1197-L1/0001-default-uneak/Illumina/"
    exit 1
fi
ILLUMINA_DIR=`basename ${1}`
if [ "${ILLUMINA_DIR}" != 'Illumina' ]; then
    echo "Need to provide Illumina directory as input argument, e.g.,"
    echo "$0 /hts2/gbs/GBS0060-150717_SN609_0375_AC7EDWACXX_1197-L1/0001-default-uneak/Illumina/"
    exit 1
fi

FASTQ_FILES=`ls -1 ${1}/*s_[12345678]_fastq.txt.gz 2> /dev/null | wc -l`
if [ ${FASTQ_FILES} -eq 0 ]; then
    echo "No FASTQ files in the expected format of *s_[12345678]_fastq.txt.gz found in:"
    echo "${1}"
    exit 1
fi

echo "Flowcell,Lane,Reads"
for FASTQ_FILE in `ls -1 ${1}/*s_[12345678]_fastq.txt.gz`; do
    # Expecting the file to be in the format of: ALL_AC7EDWACXX_s_1_fastq.txt.gz
    FASTQ_FILE_NAME=`basename ${FASTQ_FILE}`
    FASTQ_FLOWCELLID=`echo ${FASTQ_FILE_NAME} | awk -F_ '{printf $2}'`
    FASTQ_LANE=`echo ${FASTQ_FILE_NAME} | awk -F_ '{printf $4}'`
    # Integer check, should be more specific checking for 1-8 (not 9)
    if [[ ${FASTQ_LANE} -lt 1 ||${FASTQ_LANE} -gt 8 ]]; then
        echo "ERROR: Expecting '${FASTQ_LANE}' to be a lane number (1 to 8) for"
        echo "       FASTQ file '${FASTQ_FILE}"
        exit 1
    fi
    FASTQ_FILE_READ_COUNT=`zcat ${FASTQ_FILE} | grep -c ^+$`
    echo "${FASTQ_FLOWCELLID},${FASTQ_LANE},${FASTQ_FILE_READ_COUNT}"
done

