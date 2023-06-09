# Summary
Wrapper scripts to facilitate the running of [v3.0 TASSEL](https://tassel.bitbucket.io/TasselArchived.html) (Trait Analysis by aSSociation, Evolution and Linkage) and [UNEAK](https://bytebucket.org/tasseladmin/tassel-5-source/wiki/docs/TasselPipelineUNEAK.pdf) (Universal Network Enabled Analysis Kit) [Genotyping by Sequencing](https://en.wikipedia.org/wiki/Genotyping_by_sequencing) (GBS) analysis pipelines from https://www.maizegenetics.net/tassel/

# Disclaimer
* These scripts are not endorsed by the [Edward Buckler Lab](https://www.maizegenetics.net/tassel/) or Cornell University
* For running TASSEL with a reference genome it is recommended that you use the [latest v5.0](https://www.maizegenetics.net/tassel)
* For running TASSEL without a reference genome the v3.0 of [UNEAK](https://bytebucket.org/tasseladmin/tassel-5-source/wiki/docs/TasselPipelineUNEAK.pdf) may still be used

# Reference
Bradbury PJ, Zhang Z, Kroon DE, Casstevens TM, Ramdoss Y, Buckler ES. (2007) [TASSEL: Software for association mapping of complex traits in diverse samples](https://tassel.bitbucket.io/docs/bradbury2007bioinformatics.pdf). *Bioinformatics* 23:2633-2635.

# Dependencies
* [TASSEL v3.0](https://tassel.bitbucket.io/TasselArchived.html)
* `bwa` ([Burrows-Wheeler Aligner](https://bio-bwa.sourceforge.net/)) (for TASSEL not UNEAK)
* `concatenate.pl` and `deconcatenate.pl` [scripts](https://bitbucket.org/khyma/igd_public) (if using the `-i` option)

# Usage
```text
./buildtassel3.bash -h

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
      For reference genomes with extrachromosomal scaffolds, 
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

```
