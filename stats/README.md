# Summary
Set of scripts to calculate [GBS](https://en.wikipedia.org/wiki/Genotyping_by_sequencing) statistics for [TASSEL](https://tassel.bitbucket.io/TasselArchived.html) v3 runs

# Description
"Failed samples (non-blank) are defined as those with less than 10% of the mean reads per sample coming from the lane on which they were sequenced" i.e.,
* [(Number of 'good barcoded TASSEL 3 reads' per barcoded sample) / ((Total reads per lane) / Number of Samples per lane)] * 100
* A good tag is defined as a read:
  * Matching the barcode + cut site remnant (for example: `CAGC` or `CTGC` for *ApeKI*)
  * Removing the barcode (leaving the cut site remnant and sequence)
  * Trimming the read to 64 bases
  * Lacking `N`s
* The last two columns "PassFailPercentage" and "PassFail" in the CSV file are of interest.

# Scripts
Run `buildstats.bash` against your TASSEL output directory; this is the main wrapper script, which calls the other scripts

## Usage
[Discussion](https://groups.google.com/g/tassel/c/f6Vw9tD3mcI/m/sEqzQFW_DwAJ) on the use of [passfail.pl](passfail.pl)
```console
$ ./passfail.pl

Usage: ./passfail.pl -b countbarcodes_file -r countreads_file [-p percentage]

-b, --barcodes
       countbarcodes.csv produced by countbarcodes.pl
-r, --reads
       countreads.csv (reads per flowcell lane) in the format:
       Flowcell,Lane,Reads
-p, --percentage
       Optional percentage cutoff (default is 10%) to determine if a
       sample is defined as either 'pass' or 'fail' per:
       (Number of 'good barcoded TASSEL 3 reads' per barcoded sample)
       ((Total reads per lane) / (Number of Samples per lane))
-h, --help
       This usage information.
```
