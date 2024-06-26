# Summary
Wrapper scripts to facilitate the running of [TASSEL](https://tassel.bitbucket.io/TasselArchived.html) (Trait Analysis by aSSociation, Evolution and Linkage) and [UNEAK](https://bytebucket.org/tasseladmin/tassel-5-source/wiki/docs/TasselPipelineUNEAK.pdf) (Universal Network Enabled Analysis Kit) [Genotyping by Sequencing](https://en.wikipedia.org/wiki/Genotyping_by_sequencing) (GBS) v3.0 analysis pipelines from https://www.maizegenetics.net/tassel/

# Disclaimer
* These scripts are not endorsed by the [Edward Buckler Lab](https://www.maizegenetics.net/tassel/) or Cornell University
* For running TASSEL with a reference genome it is recommended that you use the [latest v5.0](https://www.maizegenetics.net/tassel)
  * `buildtassel3.bash` will only work with TASSEL/UNEAK v3.0, not v5.0
* For running TASSEL without a reference genome the v3.0 of [UNEAK](https://bytebucket.org/tasseladmin/tassel-5-source/wiki/docs/TasselPipelineUNEAK.pdf) may still be used

# References
## TASSEL
Bradbury PJ, Zhang Z, Kroon DE, Casstevens TM, Ramdoss Y, Buckler ES. (2007) [TASSEL: Software for association mapping of complex traits in diverse samples](https://tassel.bitbucket.io/docs/bradbury2007bioinformatics.pdf). *Bioinformatics* 23:2633-2635.

## UNEAK
Lu F, Lipka AE, Elshire R, Cherney JH, Casler MD, Buckler ES, Costich DE. [Switchgrass genomic diversity, ploidy, and evolution: novel insights from a network-based SNP discovery protocol](https://doi.org/10.1371/journal.pgen.1003215). *PLoS Genet*. 2013;9(1):e1003215. 

## buildtassel3
`buildtassel3.bash` used as part of:

[Henning, J. A.](https://www.ars.usda.gov/pacific-west-area/corvallis-or/forage-seed-and-cereal-research-unit/people/john-henning/), Coggins, J., & [Peterson, M.](https://orcid.org/0000-0003-4422-4463) (2015). Simple [SNP](https://en.wikipedia.org/wiki/Single-nucleotide_polymorphism)-based minimal marker genotyping for *[Humulus lupulus](https://en.wikipedia.org/wiki/Humulus_lupulus)* L. identification and variety validation. *BMC Research Notes*, 8(1), 542. doi:[10.1186/s13104-015-1492-2](https://doi.org/10.1186/s13104-015-1492-2)

# Dependencies
* [TASSEL v3.0](https://tassel.bitbucket.io/TasselArchived.html)
* `bwa` ([Burrows-Wheeler Aligner](https://bio-bwa.sourceforge.net/)) (for TASSEL not UNEAK)
  * Note: `bowtie2` ([Bowtie 2](https://bowtie-bio.sourceforge.net/bowtie2/index.shtml)) is not implemented in `buildtassel3.bash` ([#2](/../../issues/2))
* `concatenate.pl` and `deconcatenate.pl` [scripts](https://bitbucket.org/khyma/igd_public) (if using the `-i` option) from [Katie Hyma](https://bitbucket.org/khyma)

# Usage
```console
$ ./buildtassel3.bash -h

--------
OVERVIEW
--------
1) Setup run directory: './buildtassel3-itest.bash -s -p pipeline -o outputdir'
2) Update Key, FASTQ, and optional reference genome files in outputdir
3) Test with dry run:   './buildtassel3-itest.bash -d -p pipeline -o outputdir'
4) Run pipeline:        './buildtassel3-itest.bash    -p pipeline -o outputdir'

Usage: ./buildtassel3-itest.bash -p pipeline -o outputdir [-a alignment] [-i] [-e enzyme] [-c config] [-m memory] [-t threads] [-s] [-f] [-d] [-h]

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
      If using SGE specify the appropriate number of processors.

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

```

## Example
```console
$ ./buildtassel3.bash -s -p tassel -o ./testo

-----------------------------------------------------------------------
Default directory structure created in ./testo
-----------------------------------------------------------------------

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


---------
REFERENCE
---------

The above information can also be found at:
KEY FILE        : ./testo/README.txt
FASTQ FILE(S)   : ./testo/Illumina/README.txt
REFERENCE GENOME: ./testo/referencegenome/README.txt

Run './buildtassel3.bash -d -p tassel -o ./testo' to test your setup.
Run './buildtassel3.bash    -p tassel -o ./testo' to process your data.

Try './buildtassel3.bash -h' for more information.

```
```console
$ find ./testo
./testo
./testo/Illumina
./testo/Illumina/README.txt
./testo/key
./testo/tagCounts
./testo/mergedTagCounts
./testo/tagPair
./testo/tagsByTaxa
./testo/mapInfo
./testo/hapMap
./testo/vcf
./testo/support
./testo/referencegenome
./testo/referencegenome/README.txt
./testo/tbt
./testo/topm
./testo/mergedtbt
./testo/key.csv
./testo/README.txt
$ cat ./testo/key.csv 
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
