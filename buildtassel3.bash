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

#######################################
# 20131108 matthew@cgrb.oregonstate.edu
# buildtassel.bash
#
# Wrapper script for TASSEL and UNEAK v3.0 pipelines
# http://www.maizegenetics.net/tassel/ 
# 
# NOTES:
# 1) This script expects that the tassel3config.txt file exists
#    in the same directory as this script. If it does not then
#    specify the location of the configuration file via -c
#
# 2) If you are not running this under SGE it is *highly* advised
#    that you use bash's `nohup` to capture all stdout/stderr to file.
# 
# 3) If you want this script to detect when Java runs out of memory
#    you need to modify the TASSEL run_pipeline.pl script as described
#    below. If Java runs out of memory without the below modification
#    it will continue to exit on failure with a zero status code 
#    (success) and the pipeline will continue to run but will produce 
#    incomplete or incorrect results.
###
IFS="
"
###################################################
# DEFAULT SETTINGS not encoded in tassel3config.txt
###################################################
DEFAULT_ENZYME=ApeKI   # CGRB default and only enzyme currently offered
DEFAULT_MEMORY=30      # 30 GB (TasselPipelineGBS.pdf recommends at least 16 GB)
                       # SGE reports gbs0 as having less than 32 GB via qhost
                       # What do I do when the “Exception java.lang.OutOfMemoryError” occurs?
                       # http://www.maizegenetics.net/tassel-faqs
                       # SGE reports gbs0 as having
DEFAULT_THREADS=1      # Number of processors (cores) used for bwa and bowtie2
TASSEL_30_RUN_PIPELINE_CMD=/local/cluster/gbs/utils/tassel3.0_standalone-BUILD20140626/run_pipeline.pl
# NOTICE: To enable Java Out of Memory (OOM) Exception Detections you will
#         need to modify the run_pipeline.pl script (TASSEL_30_RUN_PIPELINE_CMD)
#
# FROM:
# tail -n3 run_pipeline.pl
# print "Tassel Pipeline Arguments: " . "@args\n";
# 
# system "java -classpath '$CP' $java_mem_min $java_mem_max net.maizegenetics.pipeline.TasselPipeline @args";
#
# TO (note the addition of $java_oom on the second line):
# tail -n3 run_pipeline.pl
# print "Tassel Pipeline Arguments: " . "@args\n";
# my $java_oom = "-XX:OnOutOfMemoryError=\"kill -9 %p && date > /tmp/`whoami`-buildtassel3-javaoom\"";
# system "java -classpath '$CP' $java_oom $java_mem_min $java_mem_max net.maizegenetics.pipeline.TasselPipeline @args";
# 
# When a Java plugin runs out of memory it will invoke the kill, e.g.,
# java.lang.OutOfMemoryError: Java heap space
# -XX:OnOutOfMemoryError="kill -9 %p && date > /tmp/petersm3-buildtassel3-javaoom"
#   Executing /bin/sh -c "kill -9 17645 && date > /tmp/petersm3-buildtassel3-javaoom"...
#
# WARNING: This is not a perfect solution as a race condition could technically exist within a sub
#          1 second window if more than one of this script were run by the same user at the same time.
######################
# END DEFAULT SETTINGS
######################
javaoom() {
    echo "ERROR: Java out of memory error!"
    echo "       Increase amount of RAM and re-run from scratch."
    tryhelp
}

# Make sure TASSEL 3.0 CLI pipeline is installed and executeable
if [ ! -x ${TASSEL_30_RUN_PIPELINE_CMD} ]; then
    echo "ERROR: ${TASSEL_30_RUN_PIPELINE_CMD} is not executeable, existing script."
    exit 1
fi

# Make sure Java is in our path and working
if [ `java -version 2>&1 | grep -i 'java version' | wc -l` -ne 1 ]; then
    echo "ERROR: java does not appear to be properly setup."
    echo -n "       `which java` returns:"
    which java
    exit 1
fi

usage () {
    echo ""
    echo "--------"
    echo "OVERVIEW"
    echo "--------"
    echo "1) Setup run directory: '$0 -s -p pipeline -o outputdir'"
    echo "2) Update Key, FASTQ, and optional reference genome files in outputdir"
    echo "3) Test with dry run:   '$0 -d -p pipeline -o outputdir'"
    echo "4) Run pipeline:        '$0    -p pipeline -o outputdir'"
    echo ""
    echo "Usage: $0 -p pipeline -o outputdir [-a alignment] [-i] [-e enzyme] [-c config] [-m memory] [-t threads] [-s] [-f] [-d] [-h]"
cat <<'EOF'

-p pipeline
      Analysis pipeline to run: 'tassel' or 'uneak'

-o outputdir
      Directory holding the output of the entire TASSEL/UNEAK run.
      Script assumes you have already run: -s -p pipeline -o outputdir
      to create the appropriate directory structure for your run.
      It assumes there is a correctly formatted 'outputdir'/key.csv
      file, correctly named FASTQ file in 'outputdir'/Illumina and
      for TASSEL it assumes there is a single (correctly formatted) 
      reference genome in 'outputdir'/referencegenome.

-a alignment
      'bwa' or 'bowtie2' for TASSEL. UNEAK does not use alignments.
      If not specified for -p tassel then it will default to 'bwa'
      NOTE: bowtie2 is not implemented at this time.

-i 
      Use (de)concatenate scripts to automatically correct the
      indices (coordinates) of a hapmap for a pseudochromosome
      composed of a large set, e.g., 100 to 10000000, scaffolds. 
      Only scaffolds should be in the single FASTA file in the 
      'outputdir'/referencegenome directory. If you have other
      "real" chromosomes perform a separate TASSEL run.
      See: https://bitbucket.org/khyma/igd_public
      For reference genomes with extra chromosomal scaffolds, 
      there is no relationship between the marker rs# in the hapMap
      file and marker scaffold or position. For more details see:
      'outputdir'/referencegenome/README.txt
      Use with -p tassel (and default -a bwa)

-e enzyme
      Restriction enzyme used. Default is 'ApeKI'

-c config
      Configuration file containing custom pipeline arguments.
      By default this script uses tassel3config.txt located in the
      same directory. If other arguments are needed make a copy of
      tassel3config.txt, edit the file, and then supply via -c

-m memory
      Amount of RAM used by the pipeline, minimum default of 32 GB.
      TASSEL has run out of memory using 16 GB processing MiSeq data
      If using SGE specify the appropriate amount of RAM.

-t threads
      Threads (processors) used by bwa or bowtie2, defaults to 1.
      If using SGE specify the approriate number of processors.

-s
      Setup the initial directory structure in 'outputdir' to hold
      the FASTQ file(s), key file, and optional reference genome.
      Setup requires the following argument: -p pipeline -o outputdir

-f    
      Force the creation of a setup directory if assets such as key.csv 
      and the Illumina directory already exit. Use with -s

-d
      Dry run to check setup, e.g., correctly formatted key and
      FASTQ file(s). The analysis pipeline will not be invoked.
      It's recommend to run -d several times to ensure your setup
      is correct before invoking a real run without -d. Dry run
      requires the following arguments: -p pipeline and -o outputdir

-h    Show this usage information.

EOF
    exit 0
}

# http://wiki.bash-hackers.org/howto/getopts_tutorial
while getopts ":p:o:a:e:c:m:t:sfdih" opt; do
    case $opt in
    p)
        PIPELINE_ORIG=${OPTARG}
        PIPELINE=`echo -n "${PIPELINE_ORIG}" | tr '[:upper:]' '[:lower:]'`
        ;;
    o)
        OUTPUT_DIR=${OPTARG}
        ;;
    a)  
        ALIGNMENT=${OPTARG}
        ;;
    e)  
        ENZYME=${OPTARG}
        ;;
    c)
        CONFIG_FILE=${OPTARG}
        ;;
    m)
        MEMORY=${OPTARG}
        ;;
    t)
        THREADS=${OPTARG}
        ;;
    s)
        SETUP=1
        ;;
    f)
        FORCE=1
        ;;
    d)
        DRYRUN=1
        ;;
    i) 
        INDEX=1
        ;;
    h)
        usage
        exit 1
        ;;
    \?)
        echo ""
        echo "Invalid option: -${OPTARG}"
        usage
        ;;
    :)
        usage
        ;;
    esac
done

# If nothing is supplied via command line for main arguments
if [ -z "${PIPELINE}" ] && [ -z "${OUTPUT_DIR}" ]; then
    usage
fi

#######################
# GLOBAL VARIABLE SETUP
#######################

# If -e enzyme, -m memory, -t threads was not passed then set it
if [ -z "${ENZYME}" ]; then
    ENZYME=${DEFAULT_ENZYME}
fi
if [ -z "${MEMORY}" ]; then
    MEMORY=${DEFAULT_MEMORY}
fi
if [ -z "${THREADS}" ]; then
    THREADS=${DEFAULT_THREADS}
fi

#################
# DIRECTORY SETUP
#################

tryhelp() {
    echo ""
    echo "Try '$0 -h' for more information."
    echo ""
    exit 1
}

# 20140609 petersm3
if [ "${DRYRUN}" == 1 ] && [ "${SETUP}" == 1 ]; then
   echo "ERROR: Run setup first (-s), update assets: Illumina Fastq file(s), key.csv,"
   echo "       and optional reference genome, and then perform a dry run (-d)."
   tryhelp
fi

if [ -z "${PIPELINE}" ]; then
    echo "ERROR: Pipeline not specified via -p"
    tryhelp
fi

if [ "${PIPELINE}" != 'tassel' -a "${PIPELINE}" != 'uneak' ]; then
    echo "ERROR: Incorrect pipeline specified via -p"
    tryhelp
fi

if [ "${PIPELINE}" == 'uneak' ] && [ "${INDEX}" == 1 ]; then
    echo "ERROR: Index argument not compatibile with -p uneak"
    tryhelp
fi

# Was 'tassel' or 'uneak' supplied via -p pipeline? If so, proceed with setup.
if [ "${SETUP}" == 1 ]; then
    # Was an analysis type supplied with setup?
    if [ -z "${PIPELINE}" ]; then
        echo "ERROR: Missing -p pipeline"
        tryhelp
    fi
    if [ -z "${OUTPUT_DIR}" ]; then
        echo "ERROR: Missing -o outputdir"
        tryhelp
    fi
    # If the user did not specify an argument and it picked up the next option
    # This may be left over from when -s took an argument
    if [ `echo ${OUTPUT_DIR} | grep "^-" | wc -l` == 1 ]; then
        echo "ERROR: The setup directory you specified starts with a dash."
        echo "       It looks like you forgot to include an argument to -o"
        echo "Please correct and re-run the setup."
        tryhelp
    fi
    if [ ! -d `dirname ${OUTPUT_DIR}` ]; then
        echo "ERROR: Parent directory of ${OUTPUT_DIR} does not exist!"
        echo "Please correct and re-run the setup."
        tryhelp
    fi
    if [ ! -w `dirname ${OUTPUT_DIR}` ]; then
        # Catch write permission errors before you attempt setup
        echo "ERROR: You do not have write permission to create ${OUTPUT_DIR}"
        echo "Please correct and re-run the setup."
        tryhelp
    fi
    # See if this directory already exists, we do not want to overwrite it
    if [ -d ${OUTPUT_DIR} ]; then
        if [ ! -n "${FORCE}" ]; then
            echo "ERROR: ${OUTPUT_DIR} already exists, not overwriting."
            echo "Use the -f option to force."
            echo "Please correct and re-run the setup."
            tryhelp
        fi
    fi

    ############################################
    # SETUP outputdir for either TASSEL or UNEAK
    ############################################
  
    # UNEAK has its own plugin for creating the default directories
    # Reusing the UCreatWorkingDirPlugin to create TASSEL directories
    2>&1 ${TASSEL_30_RUN_PIPELINE_CMD} -fork1 -UCreatWorkingDirPlugin -w ${OUTPUT_DIR} -endPlugin -runfork1 > /dev/null
    if [ $? -eq 0 ]; then
        echo ""
        echo "-----------------------------------------------------------------------"
        echo "Default directory structure created in ${OUTPUT_DIR}"
        echo "-----------------------------------------------------------------------"
        echo ""
    else
        echo "Creation of directory structure failed at ${OUTPUT_DIR}"
        exit 1
    fi

    # Create directory to hold VCF file from tbt2vcfPlugin
    mkdir -p ${OUTPUT_DIR}/vcf
    # Creatqe directory to hold copy of config file for reference and
    # arguments passed to buildtassel3.bash
    mkdir -p ${OUTPUT_DIR}/support

    if [ ${PIPELINE} == 'tassel' ]; then
        mkdir -p ${OUTPUT_DIR}/referencegenome
        mkdir -p ${OUTPUT_DIR}/tbt
        mkdir -p ${OUTPUT_DIR}/topm
        mkdir -p ${OUTPUT_DIR}/mergedtbt
        # Possibly put these outputs just in the top level hapMap directory
        # hapMap/unfilt (for output from TagsToSNPByAlignmentPlugin)
        # hapMap/mergedSNPs (for output from MergeDuplicateSNPsPlugin)
        # hapMap/filt (for output from GBSHapMapFiltersPlugin)
        # hapMap/bpec (for output from BiparentalErrorCorrectionPlugin)
    fi

# Create sample key.csv file; do not overwrite if -f was specified
if [ ! -n "${FORCE}" ]; then
cat <<'EOF' > ${OUTPUT_DIR}/key.csv
Flowcell,Lane,Barcode,Sample,PlateName,Row,Column,LibraryPrepID,Comments
ABC12AAXX,5,CTCC,MySample001,MyPlate1,A,1,,My comment A
ABC12AAXX,5,TGCA,MySample002,MyPlate1,A,2,,My comment B
ABC12AAXX,5,ACTA,MySample003,MyPlate1,A,3,,My comment C
ABC12AAXX,6,CTCC,MySample001,MyPlate1,A,1,,My replicate A
ABC12AAXX,6,TGCA,MySample002,MyPlate1,A,2,,My replicate B
ABC12AAXX,6,ACTT,MySample004,MyPlate1,A,4,,My comment D
DEF34BBYY,1,CCAA,MySample010,MyPlate2,A,1,,My comment F
DEF34BBYY,1,CTAA,MySample011,MyPlate2,A,2,,My comment G
DEF34BBYY,1,CGAA,MySample012,MyPlate2,A,3,,My comment H
DEF34BBYY,5,CCAA,MySample010,MyPlate2,A,1,,My replicate F
DEF34BBYY,5,GTAA,MySample013,MyPlate3,A,2,,My comment G
DEF34BBYY,5,GGAC,MySample014,MyPlate3,A,3,,My comment H
EOF
fi

# Create note on how to name FASTQ files
cat <<'EOF' > ${OUTPUT_DIR}/Illumina/README.txt 
-------------
FASTQ FILE(S)
-------------

Populate the Illumina directory with a *single* gzipped FASTQ file
*per* FLOWCELL LANE using the TASSEL naming convention, e.g., 

description_FLOWCELL_s_LANE_fastq.txt.gz

For information about the FASTQ naming conventions see the 
documentation at http://www.maizegenetics.net/tassel/ for:
* TASSEL see FastqToTagCountPlugin in TasselPipelineGBS.pdf
* UNEAK see UQseqToTagCountPlugin in uneak_pipeline_documentation.pdf

cd Illumina # Example
ls -1
ALL_ABC12AAXX_s_5_fastq.txt.gz
ALL_ABC12AAXX_s_6_fastq.txt.gz
ALL_DEF34BBYY_s_1_fastq.txt.gz
ALL_DEF34BBYY_s_5_fastq.txt.gz

NOTES:
* There should be *no more* than 4 underscores (_) in the filenames.
* This pipeline uses a *single* 'fastq' file, not a (Illumina GAIIx)
  'qseq' file. If you have several fastq files from a single HiSeq 
  lane you can concatenate them together with the following:

  cd Sample_lane5
  cat *.fastq.gz > ALL_ABC12AAXX_s_5_fastq.txt.gz

* If you plan to perform a single analysis of the FASTQ files then
  place the FASTQ file(s) here for example: my-outputdir/Illumina/
* If you plan to perform multiple analyses of the FASTQ files then
  place the FASTQ file(s) in a directory *outside* of the "Illumina"
  directory and create a symblic link to that directory, e.g.:

  cd my-outputdir
  rm Illumina/README.txt    # Delete this README.txt file
  rmdir Illumina
  ln -s /data/other-Illumina-dir ./Illumina

EOF

if [ ${PIPELINE} == 'tassel' ]; then
cat <<'EOF' > ${OUTPUT_DIR}/referencegenome/README.txt
----------------
REFERENCE GENOME 
----------------

Setup a single reference genome file in the referencegenome directory.

NOTES: 
* Do NOT place any other files in this directory other than your single
  reference genome FASTA file and the default README.txt file.
* The name of your reference genome FASTA file does not matter.
* The headers on the FASTA file may only contain only single integers and
  may optionally lead with the string 'chr', e.g.,

  # Show first threee headers of sample fasta file

  grep "^>" my-outputdir/referencegenome/myref.fa | head -n3
  >1
  >2 
  >3

  # OR same example with allowed 'chr' in the header

  grep "^>" my-outputdir/referencegenome/myref.fa | head -n3
  >chr1
  >chr2
  >chr3

* The integers in the header must be in ascending order (except for -i)
* TASSEL expects that it is only going to process a small set of chromosomes 
  in the reference sequence file. If your reference genome contains hundreds 
  or hundreds of thousands of scaffolds then these should be run in an 
  independent TASSEL run using the -i option (see below for details).
* For genomes with hundreds to thousands of scaffolds, extrachromosomal 
  scaffolds must be concatenated end to end into a single pseudoscaffold for 
  TASSEL to successfully execute. This pseudoscaffold becomes "S1", and the 
  length of S1 is the sum of the lengths of all the concatenated scaffolds. 
  When SNPs are called on this scaffold, the SNP coordinates are relative to 
  S1. At the end of the Tassel pipeline, the pseudoscaffold is disassembled 
  back into its original component scaffolds, and the coordinates of the SNP
  calls on each individual scaffold are then reported in the "chrom" and "pos"
  columns (columns 3 and 4) in the hapMap file. The SNP IDs reported in the
  first column, however, retain the "S1" pseudochromosome designation, an
  underscore, and the coordinate of the SNP on the pseudochromosome. Therefore,
  THE NUMBERS IN THE RS# COLUMN (FIRST COLUMN) ARE ESSENTIALLY MEANINGLESS AND
  CAN BE IGNORED. To reformat the first column so that SNP IDs are related to
  their true scaffolds and positions, print "S" (column3)"_"(column4).

EOF
fi

cat <<'EOF' > ${OUTPUT_DIR}/README.txt
--------
KEY FILE
--------

Create an appropriate key file for your experiment, see Appendix 1 in:
* 'TASSEL 3.0 Genotyping by Sequencing (GBS) pipeline documentation' OR
* 'Tassel 3.0 UNEAK Pipeline Document'

Update the sample comma seperated value (CSV) key file (key.csv) in 
the outputdir you specified, e.g., my-outputdir/key.csv

NOTES:
* If you put values in for "LibraryPrepID" it must be an integer.
  "LibraryPrepID's are used to facilitate merging of the TagsByTaxa
   counts from replicate runs of the same library preps (on multiple flow
   cell lanes)." - TasselPipelineGBS.pdf Appendix 1: Key file example
* Processing TASSEL runs using the "production pipeline" (as oppposed to
  the "discovery pipeline") are not supported by this script, i.e., 
  The "LibraryPrepID" will not be used by this script.
* Do not create a tab sepearted value (TSV) key file. The CSV key
  file will automatically be converted to a TSV by this script.
* Do NOT place any files in the key/ directory.

EOF

cat ${OUTPUT_DIR}/README.txt
echo ""
cat ${OUTPUT_DIR}/Illumina/README.txt

# Reference genome required for TASSEL
if [ ${PIPELINE} == 'tassel' ]; then
    echo ""
    cat ${OUTPUT_DIR}/referencegenome/README.txt
fi

echo ""
echo "---------"
echo "REFERENCE"
echo "---------"
echo ""
echo "The above information can also be found at:"
echo "KEY FILE        : ${OUTPUT_DIR}/README.txt"
echo "FASTQ FILE(S)   : ${OUTPUT_DIR}/Illumina/README.txt"
if [ ${PIPELINE} == 'tassel' ]; then
    echo "REFERENCE GENOME: ${OUTPUT_DIR}/referencegenome/README.txt"
fi
echo ""
echo "Run '$0 -d -p ${PIPELINE} -o ${OUTPUT_DIR}' to test your setup."
echo "Run '$0    -p ${PIPELINE} -o ${OUTPUT_DIR}' to process your data."
tryhelp
fi 

# Assuming we are past setup and ready to run, check input arguments
# getopts will print usage if a flag is specified but argument not supplied
if [ -z "${OUTPUT_DIR}" ]; then
    echo "ERROR: Output directory not specified via -o"
    tryhelp
fi
if [ `echo ${OUTPUT_DIR} | grep "^-" | wc -l` == 1 ]; then
    echo "ERROR: The setup directory you specified starts with a dash."
    echo "       It looks like you forgot to include an argument to -o"
    echo "Please correct and re-run the setup."
    tryhelp
fi
if [ ! -d ${OUTPUT_DIR} ]; then
    echo "ERROR: Output directory ${OUTPUT_DIR} does not exist."
    tryhelp
fi

########################
# START PREFLIGHT CHECKS
########################

echo "##############################"
echo "# Starting preflight checks..."
echo "##############################"

########################################################
# TEST TO SEE IF DEFAULT DIRECTORY STRUCTURE IS IN PLACE
########################################################
if [ ! -d ${OUTPUT_DIR}/hapMap ] || [ ! -d ${OUTPUT_DIR}/mapInfo ] || [ ! -d ${OUTPUT_DIR}/mergedTagCounts ] || [ ! -d ${OUTPUT_DIR}/tagCounts ] || [ ! -d ${OUTPUT_DIR}/tagPair ] || [ ! -d ${OUTPUT_DIR}/tagsByTaxa ]; then
    echo "ERROR: ${OUTPUT_DIR} missing one of the following expected directories:"
    echo "       hapMap, mapInfo, mergedTagCounts, tagCounts, tagPair, tagsByTaxa"
    echo ""
    echo "Please check that you ran the setup correctly."
    tryhelp
fi

if [ ${PIPELINE} == 'tassel' ]; then
    if [ ! -d ${OUTPUT_DIR}/referencegenome ] || [ ! -d ${OUTPUT_DIR}/tbt ] || [ ! -d ${OUTPUT_DIR}/topm ] || [ ! -d ${OUTPUT_DIR}/mergedtbt ]; then
    echo "ERROR: ${OUTPUT_DIR} missing one of the following expected directories:"
    echo "       referencegenome, tbt, topm, mergedtbt"
    echo ""
    echo "Please check that you ran the setup correctly."
    fi
fi

###########################
# CHECK KEY AND FASTQ FILES
###########################
if [ ! -f "${OUTPUT_DIR}/key.csv" ]; then
    echo "ERROR: ${OUTPUT_DIR}/key.csv does not exist!"
    tryhelp
fi

# Go ahead and convert the key.csv file just to be safe
dos2unix -q ${OUTPUT_DIR}/key.csv

# 20150507 petersm3
# If `dos2unix` did not work to strip out ^M
if [ `cat -v ${OUTPUT_DIR}/key.csv | grep "\^M" | wc -l` -gt 0 ]; then
    echo "ERROR: ${OUTPUT_DIR}/key.csv contains ^M character(s) (DOS/Windows carriage return)"
    echo '       Correct your keyfile to remove ^M use standard UNIX \n newline characters, e.g.,'
    echo "       tr -d '\015'    < key.csv > key-remove-M.csv   # Remove ^M"
    echo "       or"
    echo "       tr  '\015' '\n' < key.csv > key-change-M.csv   # Change ^M to \\n"
    echo "       Audit your 'key-change-M.csv' file after either `tr` command and verify it."
    tryhelp
fi

if [ `head -n1 ${OUTPUT_DIR}/key.csv | grep "^Flowcell,Lane,Barcode,Sample,PlateName,Row,Column,LibraryPrepID,Comments" | wc -l` -ne 1 ]; then
    echo "ERROR: ${OUTPUT_DIR}/key.csv first row header incorrect."
    echo "Make sure your file is a CSV (commas) and *not* a TSV (tabs)."
    echo ""
    echo "The first row should be:"
    echo ""
    echo "Flowcell,Lane,Barcode,Sample,PlateName,Row,Column,LibraryPrepID,Comments"
    echo ""
    echo "Your key.csv file contains the following in the first row:"
    echo ""
    head -n1 ${OUTPUT_DIR}/key.csv
    echo ""
    tryhelp
elif [ `wc -l ${OUTPUT_DIR}/key.csv | awk '{printf $1}'` -lt 3 ]; then
    # Really we should be checking for a minimum of 24 samples but some users 
    # may run this pipeline with a subset of barcodes (for some reason?).
    echo "ERROR: There are less than 2 samples in your ${OUTPUT_DIR}/key.csv"
    echo "       Check the file's carrige returns to ensure they are UNIX format."
    echo "       The following command will show the number of lines in the file:"
    echo "       wc -l ${OUTPUT_DIR}/key.csv"
    tryhelp
fi

# Each line should have only 8 commas
LINES=`grep ',' ${OUTPUT_DIR}/key.csv | grep -v "^Flowcell"`
for LINE in ${LINES}; do
    COMMACOUNT=`grep -o ',' <<< "${LINE}" |wc -l`
    if [ ${COMMACOUNT} -ne 8 ]; then
        echo "ERROR: Each line should have 8 commas."
        echo -n "The following line has " 
        echo ${COMMACOUNT}
        echo ""
        echo ${LINE}
        echo ""
        tryhelp
    fi
done

# The last column must have a comment; doesn't matter what it is.
for LINE in ${LINES}; do
    COMMENT=`echo "${LINE}" | awk -F, '{ printf $NF }'`
    if [ -z "${COMMENT}" ]; then
        echo "ERROR: Comment field (last one) must have something in it."
        echo "Offending line:"
        echo ""
        echo ${LINE}    
        tryhelp
    fi
done

# Test to see if LibraryPrepID is specified that it's an integer
for LINE in ${LINES}; do
    LIBRARYPREPID=`echo "${LINE}" | awk -F, '{ printf $8 }'`
    if [ -n "${LIBRARYPREPID}" ]; then
        # There's something in the field, check that it's an integer
        # Cheap way to check...
        if [[ ! ${LIBRARYPREPID} =~ ^[-+]?[0-9]+$ ]]; then
            echo "LibraryPrepID '${LIBRARYPREPID}' is not a valid integer on line:"
            echo ""
            echo "${LINE}"
            tryhelp
        fi
    fi
done

# TASSEL: Check that there are no spaces or colons in the sample names
# UNEAK : Check that there are no spaces, colons, or underscores in the sample names
if [ ${PIPELINE} == 'uneak' ]; then
    if [ `awk -F, '{printf $4}' ${OUTPUT_DIR}/key.csv | grep -e ' ' -e ':' -e '_' | wc -l` -ne 0 ]; then
        echo "ERROR: There is a space (' '), colon (':'), or underscore ('_') in at"
        echo "       least one 'Sample' name in ${OUTPUT_DIR}/key.csv"
        echo "       This is not allowed according to uneak_pipleline_documentation.pdf Appendix 1"
        tryhelp
    fi
else
    # TASSEL allows underscores according to Appendix 1
    if [ `awk -F, '{printf $4}' ${OUTPUT_DIR}/key.csv | grep -e ' ' -e ':' | wc -l` -ne 0 ]; then
        echo "ERROR: There is a space (' ') or colon (':') in at least"
        echo "       one 'Sample' name in ${OUTPUT_DIR}/key.csv"
        echo "       This is not allowed according to TasselPipelineGBS.pdf Appendix 1"
        tryhelp
    fi
fi

# 20150807 petersm3 Check to see if there are spaces in the PlateName field
# Tthis causes UNEAK GBSHapMapFiltersPlugin to fail; unsure about TASSEL
if [ `awk -F, '{printf $5"\n"}' ${OUTPUT_DIR}/key.csv | grep ' ' | wc -l` -ne 0 ]; then
    echo "ERROR: There is at least one space (' ') in at least one 'PlateRecord' entry"
    echo "       in ${OUTPUT_DIR}/key.csv"
    echo "       Spaces in this field causes the GBSHapMapFiltersPlugin to fail."
    tryhelp
fi

# 20140609 petersm3
# Check to see if the user did not edit key.csv for their run and left the default ABC12AAXX
if [ `grep 'ABC12AAXX' ${OUTPUT_DIR}/key.csv | wc -l` -ne 0 ]; then
    echo "ERROR: It looks like ${OUTPUT_DIR}/key.csv has not been updated for your experiment."
    echo "       For example the sample flow cell 'ABC12AAXX' is in your key file."
    echo ""
    echo "       Please take the time to craft a correctly formatted key file."
    echo "       (See TASSEL or UNEAK pipeline documentation Appendix 1)"
    echo ""
    tryhelp
fi

# 20140609 petersm3 Test that the Illumina FASTQ files naming convention contains 4 underscores:
#                   description_FLOWCELL_s_LANE_fastq.txt.gz

for FASTQ_FILE in `ls -1 ${OUTPUT_DIR}/Illumina/*fastq.txt.gz`; do
    FASTQ_FILE_BASENAME=`echo ${FASTQ_FILE} | xargs basename`
    if [ `echo ${FASTQ_FILE_BASENAME} | awk -F "_" '{printf NF-1}'` -ne 4 ]; then
        echo "ERROR: The FASTQ file ${OUTPUT_DIR}/Illumina/${FASTQ_FILE_BASENAME}"
        echo "       does not conform to the naming convetion (only 4 underscores '_'):"
        echo "       description_FLOWCELL_s_LANE_fastq.txt.gz"
        tryhelp
    fi
done

# 20140609 petersm3 There needs to be at least one fastq.txt.gz file in Illumina directory
# The unwritte test code below will eventually replace this simple test
if [ `ls -1 ${OUTPUT_DIR}/Illumina/*fastq.txt.gz 2> /dev/null | wc -l` -lt 1 ]; then
    echo "ERROR: No *fastq.txt.gz files detected in ${OUTPUT_DIR}/Illumina"
    tryhelp
fi

# 20150507 petersm3 Correlate that FASTQ files exist for multiple flowcell lanes
# For example the key.csv file would contain definitions for 2 flowcells with 2 lanes each:
#
# Flowcell,Lane,Barcode,Sample,PlateName,Row,Column,LibraryPrepID,Comments
# ABC12AAXX,5,CTCC,MySample001,MyPlate1,A,1,,My comment A
# ABC12AAXX,6,CTCC,MySample001,MyPlate1,A,1,,My replicate A
# DEF34BBYY,1,CCAA,MySample010,MyPlate2,A,1,,My comment F
# DEF34BBYY,5,CCAA,MySample010,MyPlate2,A,1,,My replicate F
#
# The script should correlate the above to verify the appropriate FASTQ are in Illumina/
# Illumina/ALL_ABC12AAXX_s_5_fastq.txt.gz
# Illumina/ALL_ABC12AAXX_s_6_fastq.txt.gz
# Illumina/ALL_DEF34BBYY_s_1_fastq.txt.gz
# Illumina/ALL_DEF34BBYY_s_5_fastq.txt.gz
#
# If the key file specifies a flowcell lane and there is no corresponding fastq.txt.gz file then
# you will see TASSEL errors such as:
# Error with setupBarcodeFiles: java.lang.ArrayIndexOutOfBoundsException: 0
# Total barcodes found in lane:0
# Total barcodes found in lane:0
# No barcodes found.  Skipping this flowcell lane.

FLOWCELL_LANES=`grep -v "^Flowcell" ${OUTPUT_DIR}/key.csv |tr ',' '_' | awk -F_ '{print $1"_s_"$2}' | sort -u`
for FLOWCELL_LANE in ${FLOWCELL_LANES}; do
    FLOWCELL_LANE_COUNT=`ls -1 ${OUTPUT_DIR}/Illumina/*${FLOWCELL_LANE}*fastq.txt.gz 2> /dev/null | wc -l`
    if [ ${FLOWCELL_LANE_COUNT} -ne 1 ]; then
        echo "ERROR: Illumina/*${FLOWCELL_LANE}*.fastq.txt.gz file matching key.csv entry not found!"
        echo "       There should only be one FASTQ file per each unique flow cell lane."
        echo ""
        tryhelp
    fi
done

#########################################################
# PARSE TASSEL/UNEAK CONFIGURATION PARAMETERS (ARGUMENTS)
#########################################################

# If alternate configuration file set
if [ -n "${CONFIG_FILE}" ]; then
    if [ ! -f ${CONFIG_FILE} ]; then
        echo "ERROR: Configuration file ${CONFIG_FILE} does not exist."
        tryhelp
    else
        TASSELCONFIG_FILE=${CONFIG_FILE}
    fi
else
    # Use default configuration
    BUILDTASSEL_DIR=`dirname $0`
    # Test if default configuration file exists in the same directory as buildtassel.bash
    if [ ! -f ${BUILDTASSEL_DIR}/tassel3config.txt ]; then
        echo "ERROR: Default configuration file does not exist at ${BUILDTASSEL_DIR}/tassel3config.txt"
        tryhelp
    else
        TASSELCONFIG_FILE=${BUILDTASSEL_DIR}/tassel3config.txt
    fi
fi

# Test to see if the config file looks properly formed
# Expecting three VERSION_ variables to be in every file as a sanity check
if [ `grep -e "^VERSION_DATE" -e "^VERSION_NAME" -e "^VERSION_DESC" ${TASSELCONFIG_FILE} | wc -l` -lt 3 ]; then
    echo "ERROR: Configuration file does NOT look properly formed."
    echo "       VERSION_ variables missing from ${TASSELCONFIG_FILE}"
    tryhelp
else
    # Setup all variables in configuration file
    source ${TASSELCONFIG_FILE}
fi

# Do not overwrite directory if there is already data in there
if [ `ls -1 ${OUTPUT_DIR}/tagCounts | wc -l` -ne 0 ]; then
    echo "ERROR: It looks like you have already processed ${OUTPUT_DIR}"
    echo "       There are files in ${OUTPUT_DIR}/tagCounts"
    echo "       This script will not overwrite your data, exiting..."
    tryhelp
fi

###################################
# Reference genome tests for TASSEL
###################################
if [ ${PIPELINE} == 'tassel' ]; then
    # Test to see if there is a referencegenome directory setup
    if [ ! -d ${OUTPUT_DIR}/referencegenome ]; then
        echo "ERROR: ${OUTPUT_DIR}/referencegenome directory not found!" 
        tryhelp
    fi
    # Test to see if there is a single reference genome file, ignore sub directories
    if [ `find -L ${OUTPUT_DIR}/referencegenome -maxdepth 1 -type f | grep -v -e README.txt -e "\.amb$" -e "\.ann$" -e "\.bwt$" -e "\.pac$" -e "\.sa$" | wc -l` -ne 1 ]; then
        echo "ERROR: There does not appear to be a SINGLE reference genome setup."
        echo "       (README.txt file is ignored)"
        echo ""
        echo "ls -1a ${OUTPUT_DIR}/referencegenome"
        ls -1 ${OUTPUT_DIR}/referencegenome
        tryhelp
    fi
    # Test to see if the reference genome is properly formatted
    REFGENOME=`find -L ${OUTPUT_DIR}/referencegenome -maxdepth 1 -type f | grep -v -e README.txt -e "\.amb$" -e "\.ann$" -e "\.bwt$" -e "\.pac$" -e "\.sa$" | xargs basename`
    if [ `grep "^>" ${OUTPUT_DIR}/referencegenome/${REFGENOME} | wc -l` -lt 1 ]; then
        echo "ERROR: ${REFGENOME} does not appear to be properly formatted."
        echo "       There should be at least one header starting with: >"
        tryhelp
    fi
    # Test to see if the reference genome file is setup correctly for TASSEL
    REFGENOME_HEADERS=`grep "^>" ${OUTPUT_DIR}/referencegenome/${REFGENOME} | sed 's/^>chr//g' | sed 's/[0-9]*//g' | tr -d '>' | tr -d '\n'`
    if [ -n "${REFGENOME_HEADERS}" ]; then
        echo "ERROR: ${OUTPUT_DIR}/referencegenome/${REFGENOME} contains"
        echo "       characters in the headers other than: >, chr, 0-9"
        echo "       See referencegenome/README.txt for details on header formatting."
        tryhelp
    fi
 
    # If it looks like a pseudochromosome set of scaffolding was provided but no -i specified
    HEADER_COUNT=`grep -c "^>" "${OUTPUT_DIR}/referencegenome/${REFGENOME}"`
    if [ ${HEADER_COUNT} -gt 100 ] && [ "${INDEX}" != '1' ]; then
        echo "ERROR: You have ${HEADER_COUNT} headers in your reference genome"
        echo "       and you did not treat it as a pseudochromosome via -i"
        echo "       Please check your configuration and re-run."
        tryhelp
    fi

    # Test to see if integer headers are in sequential order
    REFGENOME_HEADERS_LIST_RAW=`grep "^>" ${OUTPUT_DIR}/referencegenome/${REFGENOME} | sed 's/^>chr//g' | tr -d '>' | tr -d '\n'`
    REFGENOME_HEADERS_LIST_SORTED=`grep "^>" ${OUTPUT_DIR}/referencegenome/${REFGENOME} | sed 's/^>chr//g' | tr -d '>' | sort -n | tr -d '\n'`
    # Pseudochromosome scaffolding numbers do not need to be in sequence order
    if [ "${INDEX}" != '1' ]; then
        # Compare unsorted list of chr numbers vs. sorted list of chr numbers
        # If they match then then chr headers are in sequential order as requred
        if [ "${REFGENOME_HEADERS_LIST_RAW}" != "${REFGENOME_HEADERS_LIST_SORTED}" ]; then
            echo "ERROR: Numeric chromosome headers are NOT in sequential order."
            echo "       Please correct and re-run"
            tryhelp
        fi
    fi
fi

###########################
# Alignment algorithm check
###########################
if [ "${PIPELINE}" == 'tassel' ]; then
    # Default to bwa if not specified via -a
    if [ -z "${ALIGNMENT}" ]; then
        ALIGNMENT=bwa
    fi
    if [ "${ALIGNMENT}" != 'bwa' -a "${ALIGNMENT}" != 'bowtie2' ]; then
        echo "ERROR: Incorrect alignment specified via -a"
        tryhelp
    fi
    # bowtie2 not implemented yet
    if [ "${ALIGNMENT}" == 'bowtie2' ]; then
        echo "ERROR: bowtie2 not implemented yet, please use bwa"
        tryhelp
    fi
    # Make sure the bwa binary is available
    if [ "${ALIGNMENT}" == 'bwa' ] && [ ! -e ${BWA_CMD} ]; then
        echo "ERROR: bwa not found at: ${BWA_CMD}"
        tryhelp
    fi
    # Test if Cornell scripts are available if -i is passed
    # https://bitbucket.org/khyma/igd_public
    if [ "${INDEX}" == '1' ]; then
        if [ ! -e ${CONCATENATE_CMD} ]; then
            echo "ERROR: concatenate.pl not found at: ${CONCATENATE_CMD}"
        fi
        if [ ! -e ${DECONCATENATE_CMD} ]; then
            echo "ERROR: deconcatenate.pl not found at: ${DECONCATENATE_CMD}"
        fi
    fi
fi

##############################################################
# Check to see if there are any Java OOM error files left over
# This should never happen (unless the race condition occurs)
##############################################################
if [ -f /tmp/`whoami`-buildtassel3-javaoom ]; then
    echo "ERROR: Java Out of Memory error file left over in /tmp from a previous run:"
    echo ""
    ls -l /tmp/`whoami`-buildtassel3-javaoom
    echo ""
    echo "Remove file and re-run"
    tryhelp
fi

#############################
# Convert CSV to TSV for user
#############################
if [ -z "${DRYRUN}" ]; then
    # Ok to overwrite if already exists
    cat ${OUTPUT_DIR}/key.csv | tr ',' '\t' > ${OUTPUT_DIR}/key/key.tsv
fi

###################
# LOGGING FUNCTIONS
###################

startplugin() {
    hashes
    echo -n "START $1 : "
    date
    hashes
}
endplugin() {
    hashes
    echo -n "END $1 : "
    date
    hashes
}
hashes() {
    echo "###############################################################################"
}

#####################
# Plugin error checks
#####################

EXCEPTIONCHECK="${OUTPUT_DIR}/support/buildtassel3-exceptioncheck.txt"
JAVAOOMCHECK=/tmp/`whoami`-buildtassel3-javaoom

javaoomcheck() {
    # Must modify run_pipeline.pl to work, see instructions at top of file
    if [ -f ${JAVAOOMCHECK} ]; then
        rm -f ${JAVAOOMCHECK}
        echo ""
        echo "ERROR: Java ran out of memory, script stopped!"
        echo "       Clean up your output directory with the assets that have been written so far, e.g.,"
        echo ""
        echo "cd ${OUTPUT_DIR}"
        echo "rm -f mapInfo/* mergedTagCounts/* tagCounts/* tagPair/* tagsByTaxa/* vcf/* hapMap/* hapMap/mergedtbt/* hapMap/tbt/* hapMap/topm/* support/*"
        echo "" 
        echo "       and re-run this script with additional memory allocated via -m" 
        tryhelp
    fi
}

# Detect Java Exceptions when executing TASSEL plugins
if [ -f ${EXCEPTIONCHECK} ]; then
    echo "EXCEPTIONCHECK file from previous run still exists:"
    echo ""
    echo "${EXCEPTIONCHECK}"
    echo ""
    echo "Please remove and re-run script."
    tryhelp
fi

exceptioncheck() {
    if [ `grep "^Exception" ${EXCEPTIONCHECK} | wc -l` -gt 0 ]; then
        echo ""
        echo "ERROR: Java Exception detected! Stopping."
        echo ""
        echo "       Clean up your output directory with the assets that have been written so far, e.g.,"
        echo "cd ${OUTPUT_DIR}"
        echo "rm -f mapInfo/* mergedTagCounts/* tagCounts/* tagPair/* tagsByTaxa/* vcf/* hapMap/* hapMap/mergedtbt
/* hapMap/tbt/* hapMap/topm/* support/*"
        echo "" 
        echo "       and re-run this script after correcting the Java Exception issue." 
        tryhelp
    fi
    # Cleanup as there was no Exception
    rm -f ${EXCEPTIONCHECK}
}


################
# START PIPELINE
################
if [ ${PIPELINE} == 'uneak' ]; then
    ###########################################
    # UNEAK PIPELINE (without reference genome)
    ###########################################

    #########################################
    # Check UNEAK tassel3config.txt VARIABLES
    # (not checking filter variables)
    #########################################

    for UNEAKVAR in UFASTQTOTAGCOUNT_PLUGIN UFASTQTOTAGCOUNT_ARG_s UFASTQTOTAGCOUNT_ARG_c UMERGETAXATAGCOUNT_ARG_t UMERGETAXATAGCOUNT_ARG_m UMERGETAXATAGCOUNT_ARG_c UTAGCOUNTTOTAGPAIR_PLUGIN UTAGCOUNTTOTAGPAIR_ARG_e UTAGPAIRTOTBT_PLUGIN UTBTTOMAPINFO_PLUGIN UMAPINFOTOHAPMAP_PLUGIN UMAPINFOTOHAPMAP_PLUGIN UMAPINFOTOHAPMAP_ARG_mnMAF UMAPINFOTOHAPMAP_ARG_mxMAF UMAPINFOTOHAPMAP_ARG_mnC UMAPINFOTOHAPMAP_ARG_mxC UFASTOTOPM_PLUGIN UMERGETAXATAGCOUNT_ARG_x; do

        if [ -z "${!UNEAKVAR}" ]; then
            echo "ERROR: ${UNEAKVAR} does not contain a value in ${TASSELCONFIG_FILE}"
            tryhelp
        fi
    done

    echo "##############################"
    echo "# ...finished preflight checks"
    echo "##############################"

    # Check if this is a "dry run", if so, exit
    if [ -n "${DRYRUN}" ]; then
        echo ""
        echo "Dry run finished and PASSED all preflight checks."
        echo "Re-run without the -d option to invoke the analysis pipeline."
        exit 0
    fi

    #############
    # START UNEAK
    #############
    startplugin "UNEAK PIPELINE"

    #############
    # Copy config
    #############

    echo "$0 " > ${OUTPUT_DIR}/support/cmd.txt
    for arg in $*; do
        echo -n "${arg} " >> ${OUTPUT_DIR}/support/cmd.txt
    done
    cp ${TASSELCONFIG_FILE} ${OUTPUT_DIR}/support/
    # 20150215 petersm3
    echo "${ENZYME}" > ${OUTPUT_DIR}/support/enzyme.txt

    # Output TASSEL version
    ${TASSEL_30_RUN_PIPELINE_CMD} | grep Version > ${OUTPUT_DIR}/support/tasselversion.txt

    ########################
    # UFastqToTagCountPlugin
    ########################
    startplugin ${UFASTQTOTAGCOUNT_PLUGIN}
    ${TASSEL_30_RUN_PIPELINE_CMD} -Xmx${MEMORY}g -fork1 -${UFASTQTOTAGCOUNT_PLUGIN} -w ${OUTPUT_DIR} -e ${ENZYME} -s ${UFASTQTOTAGCOUNT_ARG_s} -c ${UFASTQTOTAGCOUNT_ARG_c} -endPlugin -runfork1 2>&1 | tee ${EXCEPTIONCHECK}
    javaoomcheck  # Must modify run_pipeline.pl to work
    exceptioncheck
    endplugin ${UFASTQTOTAGCOUNT_PLUGIN}

    ##########################
    # UMergeTaxaTagCountPlugin
    ##########################
    startplugin ${UMERGETAXATAGCOUNT_PLUGIN}
    # 20150728 petersm3 Undocumented -x option added for -UMergeTaxaTagCountPlugin in tassel3config.txt
    # https://groups.google.com/forum/#!msg/tassel/qBcxrPapb2o/D7UTWSK_ZcYJ
    ${TASSEL_30_RUN_PIPELINE_CMD} -Xmx${MEMORY}g -fork1 -${UMERGETAXATAGCOUNT_PLUGIN} -w ${OUTPUT_DIR} -t ${UMERGETAXATAGCOUNT_ARG_t} -m ${UMERGETAXATAGCOUNT_ARG_m} -c ${UMERGETAXATAGCOUNT_ARG_c} -x ${UMERGETAXATAGCOUNT_ARG_x} -endPlugin -runfork1 2>&1 | tee ${EXCEPTIONCHECK}
    javaoomcheck  # Must modify run_pipeline.pl to work
    exceptioncheck
    endplugin ${UMERGETAXATAGCOUNT_PLUGIN}

    ##########################
    # UTagCountToTagPairPlugin
    ##########################

    startplugin ${UTAGCOUNTTOTAGPAIR_PLUGIN}
    ${TASSEL_30_RUN_PIPELINE_CMD} -Xmx${MEMORY}g -fork1 -${UTAGCOUNTTOTAGPAIR_PLUGIN} -w ${OUTPUT_DIR} -e ${UTAGCOUNTTOTAGPAIR_ARG_e} -endPlugin -runfork1 2>&1 | tee ${EXCEPTIONCHECK}
    javaoomcheck  # Must modify run_pipeline.pl to work
    exceptioncheck
    endplugin ${UTAGCOUNTTOTAGPAIR_PLUGIN}

    #####################
    # UTagPairToTBTPlugin 
    #####################
    startplugin ${UTAGPAIRTOTBT_PLUGIN}
    ${TASSEL_30_RUN_PIPELINE_CMD} -Xmx${MEMORY}g -fork1 -${UTAGPAIRTOTBT_PLUGIN} -w ${OUTPUT_DIR} -endPlugin -runfork1 2>&1 | tee ${EXCEPTIONCHECK}
    javaoomcheck  # Must modify run_pipeline.pl to work
    exceptioncheck
    endplugin ${UTAGPAIRTOTBT_PLUGIN}

    #####################
    # UTBTToMapInfoPlugin
    #####################
    startplugin ${UTBTTOMAPINFO_PLUGIN}
    ${TASSEL_30_RUN_PIPELINE_CMD} -Xmx${MEMORY}g -fork1 -${UTBTTOMAPINFO_PLUGIN} -w ${OUTPUT_DIR} -endPlugin -runfork1 2>&1 | tee ${EXCEPTIONCHECK}
    javaoomcheck  # Must modify run_pipeline.pl to work
    exceptioncheck
    endplugin ${UTBTTOMAPINFO_PLUGIN}

    ########################
    # UMapInfoToHapMapPlugin
    ########################
    startplugin ${UMAPINFOTOHAPMAP_PLUGIN}
    ${TASSEL_30_RUN_PIPELINE_CMD} -Xmx${MEMORY}g -fork1 -${UMAPINFOTOHAPMAP_PLUGIN} -w ${OUTPUT_DIR} -mnMAF ${UMAPINFOTOHAPMAP_ARG_mnMAF} -mxMAF ${UMAPINFOTOHAPMAP_ARG_mxMAF} -mnC ${UMAPINFOTOHAPMAP_ARG_mnC} -mxC ${UMAPINFOTOHAPMAP_ARG_mxC} -endPlugin -runfork1 2>&1 | tee ${EXCEPTIONCHECK}
    javaoomcheck  # Must modify run_pipeline.pl to work
    exceptioncheck
    endplugin ${UMAPINFOTOHAPMAP_PLUGIN}

    # hapMap/* files created at this point, everything following this is (optional) filtering

    ##################
    # UFasToTOPMPlugin
    ##################
    startplugin ${UFASTOTOPM_PLUGIN}
    ${TASSEL_30_RUN_PIPELINE_CMD} -Xmx${MEMORY}g -fork1 -${UFASTOTOPM_PLUGIN} -w ${OUTPUT_DIR} -endPlugin -runfork1 2>&1 | tee ${EXCEPTIONCHECK}
    javaoomcheck  # Must modify run_pipeline.pl to work
    exceptioncheck
    endplugin ${UFASTOTOPM_PLUGIN}

    ########################
    # GBSHapMapFiltersPlugin
    ########################
    
    # Test if the "Minimum value of F (inbreeding coefficient). Not tested by default." is set.
    if [ -n "${GBSHAPMAPFILTERS_ARG_mnF}" ]; then
        GBSHAPMAPFILTERS_FLAG_mnF="-mnF ${GBSHAPMAPFILTERS_ARG_mnF}" 
    fi
    # Test if the "Optional pedigree file containing fulls ample names & expected inbreeding
    # coefficient (F) for each." is set
    if [ -n "${GBSHAPMAPFILTERS_ARG_p}" ]; then
        GBSHAPMAPFILTERS_FLAG_p="-p ${GBSHAPMAPFILTERS_ARG_p}"
    fi
    # "Specifies that SNPs should be filtered for those in statistically significant LD 
    #  with at least one neighboring SNP."
    if [ "${GBSHAPMAPFILTERS_ARG_hLD}" == 'true' ]; then
        GBSHAPMAPFILTERS_FLAG_hLD='-hLD'
    fi
    # "The -mnR2 option requires that the -hLD option is invoked"
    # "Minimum R-square value for the LD filter (default: 0.01)"
    if [ -n "${GBSHAPMAPFILTERS_ARG_mnR2}" ]; then
        GBSHAPMAPFILTERS_FLAG_mnR2="-mnR2 ${GBSHAPMAPFILTERS_ARG_mnR2}"
    fi
    # "The -mnBonP option requires that the -hLD option is invoked"
    # "Minimum Bonferroni-corrected p-value for the LD filter."
    if [ -n "${GBSHAPMAPFILTERS_ARG_mnBonP}" ]; then
        GBSHAPMAPFILTERS_FLAG_mnBonP="-mnBonP ${GBSHAPMAPFILTERS_ARG_mnBonP}"
    fi

    # UNEAK creates a single hapmap only named HapMap.hmp.txt (supply to -hmp)
    # Start and end chromosomes (-sC and -eC) set to 0 as UNEAK uses no reference genome. 
    startplugin ${GBSHAPMAPFILTERS_PLUGIN}
    ${TASSEL_30_RUN_PIPELINE_CMD} -Xmx${MEMORY}g  -fork1 -${GBSHAPMAPFILTERS_PLUGIN} -hmp ${OUTPUT_DIR}/hapMap/HapMap.hmp.txt -o ${OUTPUT_DIR}/hapMap/HapMap.filtered.hmp.txt -mnTCov ${GBSHAPMAPFILTERS_ARG_mnTCov} -mnSCov ${GBSHAPMAPFILTERS_ARG_mnScov} ${GBSHAPMAPFILTERS_FLAG_mnF} ${GBSHAPMAPFILTERS_FLAG_p} -mnMAF ${GBSHAPMAPFILTERS_ARG_mnMAF} -mxMAF ${GBSHAPMAPFILTERS_ARG_mxMAF} ${GBSHAPMAPFILTERS_FLAG_hLD} ${GBSHAPMAPFILTERS_FLAG_mnR2} ${GBSHAPMAPFILTERS_FLAG_mnBonP} -sC 0 -eC 0 -endPlugin -runfork1 
    #2>&1 | tee ${EXCEPTIONCHECK}
    javaoomcheck  # Must modify run_pipeline.pl to work
    # 20140116 petersm3 Not checking for exceptions due to a possible error in the plugin, see:
    # https://groups.google.com/forum/#!topic/tassel/ESghxvayQ8g
    # exceptioncheck
    endplugin ${GBSHAPMAPFILTERS_PLUGIN}

    ###############
    # tbt2vcfPlugin
    ###############
   
    startplugin ${UNEAK_TBT2VCF_PLUGIN}
    ${TASSEL_30_RUN_PIPELINE_CMD} -Xmx${MEMORY}g  -fork1 -${UNEAK_TBT2VCF_PLUGIN} -i ${OUTPUT_DIR}/tagsByTaxa/tbt.bin -m ${OUTPUT_DIR}/mapInfo/fas.topm.txt -o ${OUTPUT_DIR}/vcf -ak ${UNEAK_TBT2VCF_ARG_ak} -mnMAF ${UNEAK_TBT2VCF_ARG_mnMAF} -mnLCov ${UNEAK_TBT2VCF_ARG_mnLCov} -s 1 -e 1 -endPlugin -runfork1 2>&1 | tee ${EXCEPTIONCHECK}
    javaoomcheck  # Must modify run_pipeline.pl to work
    exceptioncheck
    endplugin ${UNEAK_TBT2VCF_PLUGIN}

    ##############################
    # MergeDuplicateSNP_vcf_Plugin
    ##############################
    
    # This plugin is not documented
    startplugin ${MERGE_DUPLICATE_SNP_VCF_PLUGIN}
    ${TASSEL_30_RUN_PIPELINE_CMD} -Xmx${MEMORY}g  -fork1 -${MERGE_DUPLICATE_SNP_VCF_PLUGIN} -i ${OUTPUT_DIR}/vcf/tagsByTaxa.c1 -o ${OUTPUT_DIR}/vcf/c1.mergedSNPs.vcf -ak ${MERGE_DUPLICATE_SNP_VCF_ARG_ak} -endPlugin -runfork1 2>&1 | tee ${EXCEPTIONCHECK}
    javaoomcheck  # Must modify run_pipeline.pl to work
    exceptioncheck
    endplugin ${MERGE_DUPLICATE_SNP_VCF_PLUGIN}

    ###########
    # END UNEAK
    ###########
    endplugin "UNEAK PIPELINE" 
else
    #########################################
    # TASSEL PIPELINE (with reference genome)
    #########################################

    ##############################################
    # Check TASSEL tassel3config.txt VARIABLES
    # (not checking alignment or filter variables)
    ##############################################

    for TASSELVAR in FASTQTOTAGCOUNT_PLUGIN FASTQTOTAGCOUNT_ARG_s FASTQTOTAGCOUNT_ARG_c MERGEMULTIPLETAGCOUNT_PLUGIN MERGEMULTIPLETAGCOUNT_ARG_c SAMCONVERTER_PLUGIN FASTQTOTBT_PLUGIN FASTQTOTBT_ARG_c MERGETAGSBYTAXAFILES_PLUGIN MERGETAGSBYTAXAFILES_ARG_s TAGSTOSNPBYALIGNMENT_PLUGIN TAGSTOSNPBYALIGNMENT_ARG_mxSites TAGSTOSNPBYALIGNMENT_ARG_mnMAF TAGSTOSNPBYALIGNMENT_ARG_mnMAC TAGSTOSNPBYALIGNMENT_ARG_mnLCov; do

        if [ -z "${!TASSELVAR}" ]; then
            echo "ERROR: ${TASSELVAR} does not contain a value in ${TASSELCONFIG_FILE}"
            tryhelp
        fi
    done

    echo "##############################"
    echo "# ... finished preflight check"
    echo "##############################"

    # Check if this is a "dry run", if so, exit
    if [ -n "${DRYRUN}" ]; then
        echo "Dry run finished and PASSED all preflight checks."
        echo "Re-run without the -d option to invoke the analysis pipeline."
        exit 0
    fi

    ##############
    # START TASSEL
    ##############
    startplugin "TASSEL PIPELINE"

    #############
    # Copy config
    #############

    echo -n "$0 " > ${OUTPUT_DIR}/support/cmd.txt
    for arg in $*; do
        echo -n "${arg} " >> ${OUTPUT_DIR}/support/cmd.txt
    done
    cp ${TASSELCONFIG_FILE} ${OUTPUT_DIR}/support/
    if [ "${ALIGNMENT}" == 'bwa' ]; then
        # Get BWA version
        ${BWA_CMD} 2>&1 | head -n5 > ${OUTPUT_DIR}/support/bwa.txt
    fi

    # Output TASSEL version
    ${TASSEL_30_RUN_PIPELINE_CMD} | grep Version > ${OUTPUT_DIR}/support/tasselversion.txt

    # 20151119 petersm3
    echo "${ENZYME}" > ${OUTPUT_DIR}/support/enzyme.txt

    #######################
    # FastqToTagCountPlugin
    #######################
    startplugin ${FASTQTOTAGCOUNT_PLUGIN}
    ${TASSEL_30_RUN_PIPELINE_CMD} -Xmx${MEMORY}g -fork1 -${FASTQTOTAGCOUNT_PLUGIN} -i ${OUTPUT_DIR}/Illumina -o ${OUTPUT_DIR}/tagCounts -k ${OUTPUT_DIR}/key/key.tsv -e ${ENZYME} -s ${FASTQTOTAGCOUNT_ARG_s} -c ${FASTQTOTAGCOUNT_ARG_c} -endPlugin -runfork1 2>&1 | tee ${EXCEPTIONCHECK}
    javaoomcheck  # Must modify run_pipeline.pl to work
    exceptioncheck
    endplugin ${FASTQTOTAGCOUNT_PLUGIN}

    ###########################################
    # MergeMultipleTagCountPlugin to create CNT
    ###########################################

    startplugin ${MERGEMULTIPLETAGCOUNT_PLUGIN}
    ${TASSEL_30_RUN_PIPELINE_CMD} -Xmx${MEMORY}g -fork1 -${MERGEMULTIPLETAGCOUNT_PLUGIN} -i ${OUTPUT_DIR}/tagCounts -o ${OUTPUT_DIR}/mergedTagCounts/merged.cnt -c ${MERGEMULTIPLETAGCOUNT_ARG_c} -endPlugin -runfork1 2>&1 | tee ${EXCEPTIONCHECK}
    javaoomcheck  # Must modify run_pipeline.pl to work
    exceptioncheck
    endplugin ${MERGEMULTIPLETAGCOUNT_PLUGIN}

    #######################################################
    # MergeMultipleTagCountPlugin to create FASTA (via -t)
    # This eliminates the need for TagCountToFastqPlugin
    # for the TagsOnPhysicalMap (TOPM) part of the pipeline
    #######################################################

    startplugin "${MERGEMULTIPLETAGCOUNT_PLUGIN} -t"
    ${TASSEL_30_RUN_PIPELINE_CMD} -Xmx${MEMORY}g -fork1 -${MERGEMULTIPLETAGCOUNT_PLUGIN} -i ${OUTPUT_DIR}/tagCounts -o ${OUTPUT_DIR}/mergedTagCounts/merged.cnt -c ${MERGEMULTIPLETAGCOUNT_ARG_c} -t -endPlugin -runfork1 2>&1 | tee ${EXCEPTIONCHECK}
    javaoomcheck  # Must modify run_pipeline.pl to work
    exceptioncheck
    endplugin "${MERGEMULTIPLETAGCOUNT_PLUGIN} -t"

    ######################################
    # TagsOnPhysicalMap (TOPM) - bwa index
    ######################################

    startplugin "bwa index"
    ${BWA_CMD} index -a bwtsw ${OUTPUT_DIR}/referencegenome/${REFGENOME}
    endplugin "bwa index"

    ######################################
    # TagsOnPhysicalMap (TOPM) - bwa align 
    ######################################
 
    startplugin "bwa align"
    ${BWA_CMD} aln -t ${THREADS} ${OUTPUT_DIR}/referencegenome/${REFGENOME} ${OUTPUT_DIR}/mergedTagCounts/merged.cnt.fq > ${OUTPUT_DIR}/mergedTagCounts/alignedMasterTags.sai 
    endplugin "bwa align"

    ###############################################
    # TagsOnPhysicalMap (TOPM) - bwa samse (export)
    ###############################################

    startplugin "bwa samse (export)"
    ${BWA_CMD} samse ${OUTPUT_DIR}/referencegenome/${REFGENOME} ${OUTPUT_DIR}/mergedTagCounts/alignedMasterTags.sai ${OUTPUT_DIR}/mergedTagCounts/merged.cnt.fq > ${OUTPUT_DIR}/mergedTagCounts/alignedMasterTags.sam
    endplugin "bwa samse (export)"

    ##########################################
    # 20141208 petersm3 concatenate.pl the SAM
    # https://bitbucket.org/khyma/igd_public
    ##########################################

    ######################################################################################################################
    # "Please note that if your genome was “concatenated” into fake chromosomes, we have also included an index file 
    #  (projectname.sam.index) that relates the original coordinates to the fake “pseudochromosome” coordinates in the 
    #  form as follows, where realchr# is the name of the original scaffold/contig/chromosome from the reference fasta 
    #  file described in the reference genome section of this report.
    # 
    #  Fakechr#             start       length   realchr#
    #
    #  For your convenience, the final SNP calls and TOPM file have been “de-indexed” so that the chromosome and position
    #  coordinates relate to the original genome file, with chromosome names changed as needed for compatibility with 
    #  TASSEL (see genome info section for specifics).
    #
    #  If you are repeating the analysis and want to follow this procedure yourself, you will need to use the scripts 
    #  publicly available at  https://bitbucket.org/khyma/igd_public
    #
    #  You would use the script "concatenate.pl" with the .sam output from the aligner as input, and then use the result
    #  (a modified .sam file) with the TASSEL SAMConverterPlugin to create a “TOPM” file with the fake chromosomal 
    #  coordinates and continue with the pipeline from there. This script also produces the index file referenced above."
    #
    # - Katie Hyma (keh233@cornell.edu), Informatics Leader, Genomic Diversity Facility, 20141202
    ######################################################################################################################

    if [ "${INDEX}" == '1' ]; then
        startplugin "concatenate.pl on alignedMasterTags.sam"
        echo "Running: ${CONCATENATE_CMD} ${OUTPUT_DIR}/mergedTagCounts/alignedMasterTags.sam"
        ${CONCATENATE_CMD} ${OUTPUT_DIR}/mergedTagCounts/alignedMasterTags.sam
        endplugin "concatenate.pl on alignedMasterTags.sam"
    fi

    ###############################################
    # TagsOnPhysicalMap (TOPM) - SAMConverterPlugin
    ###############################################
   
    # Default SAM file created for standard reference file of chromosomes 
    ALIGNED_MASTER_TAGS_SAM='alignedMasterTags.sam'
    # If -i was supplied (for a pseudochromosome) then use the concatenated form of the SAM file
    if [ "${INDEX}" == '1' ]; then
        ALIGNED_MASTER_TAGS_SAM='alignedMasterTags.sam.concatenated'
        echo "Using ${ALIGNED_MASTER_TAGS_SAM} for ${SAMCONVERTER_PLUGIN}"
    fi

    startplugin "${SAMCONVERTER_PLUGIN}"
    ${TASSEL_30_RUN_PIPELINE_CMD} -Xmx${MEMORY}g -fork1 -${SAMCONVERTER_PLUGIN} -i ${OUTPUT_DIR}/mergedTagCounts/${ALIGNED_MASTER_TAGS_SAM} -o ${OUTPUT_DIR}/topm/masterTags.topm -endPlugin -runfork1 2>&1 | tee ${EXCEPTIONCHECK}
    javaoomcheck  # Must modify run_pipeline.pl to work
    exceptioncheck
    endplugin "${SAMCONVERTER_PLUGIN}"

    #####################################
    # TagsByTaxa (TBT) - FastqToTBTPlugin
    ######################################

    startplugin "${FASTQTOTBT_PLUGIN}"
    ${TASSEL_30_RUN_PIPELINE_CMD} -Xmx${MEMORY}g -fork1 -${FASTQTOTBT_PLUGIN} -i ${OUTPUT_DIR}/Illumina -o ${OUTPUT_DIR}/tbt -k ${OUTPUT_DIR}/key/key.tsv -e ${ENZYME} -t ${OUTPUT_DIR}/mergedTagCounts/merged.cnt -c ${FASTQTOTBT_ARG_c} -y -endPlugin -runfork1 2>&1 | tee ${EXCEPTIONCHECK}
    javaoomcheck  # Must modify run_pipeline.pl to work
    exceptioncheck
    endplugin "${FASTQTOTBT_PLUGIN}"
 
    ###############################################
    # TagsByTaxa (TBT) - MergeTagsByTaxaFilesPlugin
    ###############################################

    # Merge tag counts of taxa with identical names
    if [ -n "${MERGETAGSBYTAXAFILES_ARG_x}" ]; then
        MERGETAGSBYTAXAFILES_FLAG_x="-x"
    fi
    # "Call snps in output and write to HapMap file with the provided name"
    # This is NOT documented in the 20131217 copy of TasselPipelineGBS.pdf
    if [ -n "${MERGETAGSBYTAXAFILES_ARG_h}" ]; then
        MERGETAGSBYTAXAFILES_FLAG_h="-h ${MERGETAGSBYTAXAFILES_ARG_h}"
    fi

    startplugin "${MERGETAGSBYTAXAFILES_PLUGIN}"
    ${TASSEL_30_RUN_PIPELINE_CMD} -Xmx${MEMORY}g -fork1 -${MERGETAGSBYTAXAFILES_PLUGIN} -i ${OUTPUT_DIR}/tbt/ -o ${OUTPUT_DIR}/mergedtbt/merged.tbt.byte -s ${MERGETAGSBYTAXAFILES_ARG_s} ${MERGETAGSBYTAXAFILES_FLAG_x} ${MERGETAGSBYTAXAFILES_FLAG_h} -endPlugin -runfork1 2>&1 | tee ${EXCEPTIONCHECK}
    javaoomcheck  # Must modify run_pipeline.pl to work
    exceptioncheck
    endplugin "${MERGETAGSBYTAXAFILES_PLUGIN}"
 
    #################################################
    # Merge TOPM and TBT - TagsToSNPByAlignmentPlugin
    #################################################

    # There a cleaner way to do this with a for loop and ${!var}

    # "TagsOnPhysicalMap file containing genomic position of tags"
    if [ -n "${TAGSTOSNPBYALIGNMENT_ARG_m}" ]; then
        TAGSTOSNPBYALIGNMENT_ARG_FLAG_m="-m ${TAGSTOSNPBYALIGNMENT_ARG_m}"
    fi
    # "Update TagsOnPhysicalMap file with allele calls, saved to specified file"
    if [ -n "${TAGSTOSNPBYALIGNMENT_ARG_mUpd}" ]; then
        TAGSTOSNPBYALIGNMENT_ARG_FLAG_mUpd="-mUpd ${TAGSTOSNPBYALIGNMENT_ARG_mUpd}"
    fi
    # "Minimum F (inbreeding coefficient)"
    if [ -n "${TAGSTOSNPBYALIGNMENT_ARG_mnF}" ]; then
        TAGSTOSNPBYALIGNMENT_ARG_FLAG_mnF="-mnF ${TAGSTOSNPBYALIGNMENT_ARG_mnF}"
    fi
    # "Pedigree file containing full sample names..."
    if [ -n "${TAGSTOSNPBYALIGNMENT_ARG_p}" ]; then
        TAGSTOSNPBYALIGNMENT_ARG_FLAG_p="-p ${TAGSTOSNPBYALIGNMENT_ARG_p}"
    fi
    # "Average sequencing error rate per base (used to decide between heterozygous and homozygous calls)"
    if [ -n "${TAGSTOSNPBYALIGNMENT_ARG_errRate}" ]; then
        TAGSTOSNPBYALIGNMENT_ARG_FLAG_errRate="-errRate ${TAGSTOSNPBYALIGNMENT_ARG_errRate}"
    fi
    # "Path to reference genome in fasta format..."
    if [ -n "${TAGSTOSNPBYALIGNMENT_ARG_ref}" ]; then
        TAGSTOSNPBYALIGNMENT_ARG_FLAG_ref="-ref ${TAGSTOSNPBYALIGNMENT_ARG_ref}"
    fi
    # "Include the rare alleles at site (3 or 4th states)"
    if [ "${TAGSTOSNPBYALIGNMENT_ARG_inclRare}" == 'true' ]; then
        TAGSTOSNPBYALIGNMENT_ARG_FLAG_inclRare="-inclRare"
    fi
    # "Include sites where major or minor allele is a GAP"
    if [ "${TAGSTOSNPBYALIGNMENT_ARG_inclGaps}" == 'true' ]; then
        TAGSTOSNPBYALIGNMENT_ARG_FLAG_inclGaps="-inclGaps"
    fi
    # "Include sites where the third allele is a GAP"
    if [ "${TAGSTOSNPBYALIGNMENT_ARG_callBiSNPsWGap}" == 'true' ]; then
        TAGSTOSNPBYALIGNMENT_ARG_FLAG_callBiSNPsWGap="-callBiSNPsWGap"
    fi

    STARTCHROMNUM=`grep "^>" ${OUTPUT_DIR}/referencegenome/${REFGENOME} | head -n1 | sed 's/^>chr//g' | tr -d '>' | tr -d '\n'`  
    ENDCHROMNUM=`grep "^>" ${OUTPUT_DIR}/referencegenome/${REFGENOME} | tail -n1 | sed 's/^>chr//g' | tr -d '>' | tr -d '\n'`
   
    # 20171221 petersm3
    # If Index is specified (-i) for pseudochromsome then you need to determine how
    # many psuedochromsomes where generated by the concatenate script. The assumption
    # had been just one but the Cornell concatenate.pl script has the following line:
    # if ($newoffset > 2000000000)
    # So after 2 billion bases it starts another chromosome. In most cases the scaffolding
    # is small enough to fall under this 2 billion base cutoff but for large genome 
    # scaffolding this can result in 3 pseudochromosomes or more.
    #
    # Example of a concatenated SAM file header that shows two psuedochromsomes
    # head -n3 mergedTagCounts/alignedMasterTags.sam.concatenated
    # @SQ SN:1    LN:1999808622
    # @SQ SN:2    LN:1051563968
    # length=64count=9    0   2   804443544   37  4M1I59M *   0   0   CAGCAAAAAAAAAAAAAAA ...

    if [ "${INDEX}" == '1' ]; then
        STARTCHROMNUM=1

        # Incorrect assumption that there is only 1 pseudochromosome
        #ENDCHROMNUM=1
        # Extract integer after SN:
        ENDCHROMNUM=`head -n100 ${OUTPUT_DIR}/mergedTagCounts/alignedMasterTags.sam.concatenated | grep "^@SQ" | tail -n1 | awk -F: '{print $2}' | awk '{print $1}'`
    fi

    startplugin "${TAGSTOSNPBYALIGNMENT_PLUGIN}"
    ${TASSEL_30_RUN_PIPELINE_CMD} -Xmx${MEMORY}g -fork1 -${TAGSTOSNPBYALIGNMENT_PLUGIN} -i ${OUTPUT_DIR}/mergedtbt/merged.tbt.byte -m ${OUTPUT_DIR}/topm/masterTags.topm -o ${OUTPUT_DIR}/hapMap/chr+.hmp.txt -y -sC ${STARTCHROMNUM} -eC ${ENDCHROMNUM} -y -mxSites ${TAGSTOSNPBYALIGNMENT_ARG_mxSites} -mnMAF ${TAGSTOSNPBYALIGNMENT_ARG_mnMAF} -mnMAC ${TAGSTOSNPBYALIGNMENT_ARG_mnMAC} -mnLCov ${TAGSTOSNPBYALIGNMENT_ARG_mnLCov} ${TAGSTOSNPBYALIGNMENT_ARG_FLAG_m} ${TAGSTOSNPBYALIGNMENT_ARG_FLAG_mUpd} ${TAGSTOSNPBYALIGNMENT_ARG_FLAG_mnF} ${TAGSTOSNPBYALIGNMENT_ARG_FLAG_p} ${TAGSTOSNPBYALIGNMENT_ARG_FLAG_errRate} ${TAGSTOSNPBYALIGNMENT_ARG_FLAG_ref} ${TAGSTOSNPBYALIGNMENT_ARG_FLAG_inclRare} ${TAGSTOSNPBYALIGNMENT_ARG_FLAG_inclGaps} ${TAGSTOSNPBYALIGNMENT_ARG_FLAG_callBiSNPsWGap} -endPlugin -runfork1 2>&1 | tee ${EXCEPTIONCHECK}
    javaoomcheck  # Must modify run_pipeline.pl to work
    exceptioncheck
    endplugin "${TAGSTOSNPBYALIGNMENT_PLUGIN}"

    # hapMap/* files created at this point, everything following this is (optional) filtering

    ##########################
    # MergeDuplicateSNPsPlugin
    ##########################

    # "Pedigree file containing full sample names..."
    if [ -n "${MERGEDUPLICATESNPS_ARG_p}" ]; then
        MERGEDUPLICATESNPS_FLAG_p="-p ${MERGEDUPLICATESNPS_ARG_p}"
    fi
    # "When two genotypes at a replicate SNP disagree for a taxon, call it a heterozygote."
    if [ "${MERGEDUPLICATESNPS_ARG_callHets}" == 'true' ]; then
        MERGEDUPLICATESNPS_FLAG_callHets="-callHets"
    fi
    # "When two genotypes at a replicate SNP disagree for a taxon, call it a heterozygote."
    if [ "${MERGEDUPLICATESNPS_ARG_kpUnmergDups}" == 'true' ]; then
        MERGEDUPLICATESNPS_FLAG_kpUnmergDups="-kpUnmergDup"
    fi

    startplugin "${MERGEDUPLICATESNPS_PLUGIN}"
    ${TASSEL_30_RUN_PIPELINE_CMD} -Xmx${MEMORY}g -fork1 -${MERGEDUPLICATESNPS_PLUGIN} -hmp ${OUTPUT_DIR}/hapMap/chr+.hmp.txt -o ${OUTPUT_DIR}/hapMap/chr+.snpmerged.hmp.txt -misMat ${MERGEDUPLICATESNPS_ARG_misMat} ${MERGEDUPLICATESNPS_FLAG_p} ${MERGEDUPLICATESNPS_FLAG_callHets} ${MERGEDUPLICATESNPS_FLAG_kpUnmergDups} -sC ${STARTCHROMNUM} -eC ${ENDCHROMNUM} -endPlugin -runfork1 2>&1 | tee ${EXCEPTIONCHECK}
    javaoomcheck
    exceptioncheck
    endplugin "${MERGEDUPLICATESNPS_PLUGIN}"

    ##########################
    # MergeIdenticalTaxaPlugin
    ##########################

    if [ "${MERGEIDENTICALTAXA_ARG_xHet}" == 'true' ]; then
        MERGEIDENTICALTAXA_FLAG_xHet="-xHet"
    fi

    startplugin "${MERGEIDENTICALTAXA_PLUGIN}"
    ${TASSEL_30_RUN_PIPELINE_CMD} -Xmx${MEMORY}g -fork1 -${MERGEIDENTICALTAXA_PLUGIN} -hmp ${OUTPUT_DIR}/hapMap/chr+.snpmerged.hmp.txt -o ${OUTPUT_DIR}/hapMap/chr+.taxamerged.snpmerged.hmp.txt ${MERGEIDENTICALTAXA_FLAG_xHet} -hetFreq ${MERGEIDENTICALTAXA_ARG_hetFreq} -sC ${STARTCHROMNUM} -eC ${ENDCHROMNUM} -endPlugin -runfork1 2>&1 | tee ${EXCEPTIONCHECK}
    javaoomcheck
    exceptioncheck
    endplugin "${MERGEIDENTICALTAXA_PLUGIN}"

    ###############
    # tbt2vcfPlugin
    ###############

    # This plugin is not documented 
    startplugin ${TASSEL_TBT2VCF_PLUGIN}
    ${TASSEL_30_RUN_PIPELINE_CMD} -Xmx${MEMORY}g -fork1 -${TASSEL_TBT2VCF_PLUGIN} -i ${OUTPUT_DIR}/mergedtbt/merged.tbt.byte -m ${OUTPUT_DIR}/topm/masterTags.topm -o ${OUTPUT_DIR}/vcf -ak ${TASSEL_TBT2VCF_ARG_ak} -mnMAF ${TASSEL_TBT2VCF_ARG_mnMAF} -mnLCov ${TASSEL_TBT2VCF_ARG_mnLCov} -s ${STARTCHROMNUM} -e ${ENDCHROMNUM} -endPlugin -runfork1 2>&1 | tee ${EXCEPTIONCHECK}
    javaoomcheck  # Must modify run_pipeline.pl to work
    exceptioncheck
    endplugin ${TASSEL_TBT2VCF_PLUGIN}

    ##############################
    # MergeDuplicateSNP_vcf_Plugin
    ##############################

    startplugin "${MERGEDUPLICATESNPVCF_PLUGIN}"
    for MERGEDTBT in `ls -1 ${OUTPUT_DIR}/vcf/mergedtbt*`; do 
        CHROMNUM=`echo "${MERGEDTBT}" | xargs basename | sed 's/mergedtbt\.c//g'`
        ${TASSEL_30_RUN_PIPELINE_CMD} -Xmx${MEMORY}g -fork1 -${MERGEDUPLICATESNPVCF_PLUGIN} -i ${OUTPUT_DIR}/vcf/mergedtbt.c${CHROMNUM} -o ${OUTPUT_DIR}/vcf/c${CHROMNUM}.mergedsnps.vcf -ak ${MERGEDUPLICATESNPVCF_ARG_ak} -endPlugin -runfork1 2>&1 | tee ${EXCEPTIONCHECK}
        javaoomcheck
        exceptioncheck
    done
    endplugin "${MERGEDUPLICATESNPVCF_PLUGIN}"

    ################################################################
    # 20141208 petersm3 deconcatenate.pl hapmap, vcf, and topm files 
    # https://bitbucket.org/khyma/igd_public
    ################################################################

    ########################################################################################################
    # "After calling SNPs, the script "deconcatenate.pl" can be used with a hapmap, vcf, or a text topm file 
    #  (to convert a binary TOPM file to text TOPM, so will need to use TASSEL's BinaryToTextPlugin)."
    # - Katie Hyma (keh233@cornell.edu), Informatics Leader, Genomic Diversity Facility, 20141202
    ########################################################################################################
   
    ##########################################################################################################
    # ./deconcatenate.pl 
    # 
    # perl deconcatenate.pl INPUT_FILE INDEX_FILE FILE_TYPE
    #
    # INPUT_FILE can be HapMap, VCF, or TOPM (text) format, uncompressed, sorted.
    # INDEX_FILE is the output from concatenate.pl (*.sam.index)
    # FILE_TYPE is one of the following: hapmap, vcf, or topm (case-insensitive)
    # 
    # output is directed to stdout by default, to output to a new file specify "> newfilename" after arguments
    ##########################################################################################################
 
    if [ "${INDEX}" == '1' ]; then
        # Deconcatenate HapMaps
        for HAPMAP in `ls -1 ${OUTPUT_DIR}/hapMap/*hmp.txt`; do
            startplugin "deconcatenate.pl on ${HAPMAP}"
            echo "Running: ${DECONCATENATE_CMD} ${HAPMAP} ${OUTPUT_DIR}/mergedTagCounts/alignedMasterTags.sam.index hapmap > ${HAPMAP}-deconcatenate.hmp.txt"
            ${DECONCATENATE_CMD} ${HAPMAP} ${OUTPUT_DIR}/mergedTagCounts/alignedMasterTags.sam.index hapmap > ${HAPMAP}-deconcatenate.hmp.txt
            endplugin "deconcatenate.pl on ${HAPMAP}"
        done 

        # Deconcatenate VCFs
        for VCF in `ls -1 ${OUTPUT_DIR}/vcf/*vcf`; do
            startplugin "deconcatenate.pl on ${VCF}"
            echo "Running: ${DECONCATENATE_CMD} ${VCF} ${OUTPUT_DIR}/mergedTagCounts/alignedMasterTags.sam.index vcf > ${VCF}-deconcatenate.vcf"
            ${DECONCATENATE_CMD} ${VCF} ${OUTPUT_DIR}/mergedTagCounts/alignedMasterTags.sam.index vcf > ${VCF}-deconcatenate.vcf
            endplugin "deconcatenate.pl on ${VCF}"
        done

        # Deconcatenate TOPM
        # Not deconcatinating TOPMS at this time; no need?
    fi

    ############
    # END TASSEL
    ############
    endplugin "TASSEL PIPELINE"
fi

# Provide a listing of the directory structure
ls -lR ${OUTPUT_DIR} > ${OUTPUT_DIR}/support/ls-lr.txt

# 20151119 petersm3 Added enzyme.txt written to support for TASSEL in addition to UNEAK
# 20150807 petersm3 Dry run check for spaces in key.csv field PlateName (spaces causes issues with filter step of UNEAK)
# 20150507 petersm3 Dry run check for ^M, check for unique flow cell lane FASTQ files matching key.csv, -i documentation update from Kelly
# 20141208 petersm3 Retooling to use Cornell scripts for scaffolding (https://bitbucket.org/khyma/igd_public)
#
# Copyright 2015 Oregon State University.
# All Rights Reserved. 
# 
# petersm3@cgrb.oregonstate.edu
# vim: set expandtab tabstop=4 shiftwidth=4 softtabstop=4: 
