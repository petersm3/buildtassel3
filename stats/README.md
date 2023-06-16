# Summary
Set of scripts to calculate [GBS](https://en.wikipedia.org/wiki/Genotyping_by_sequencing) statistics for [TASSEL](https://tassel.bitbucket.io/TasselArchived.html) v3 runs

# Scripts
Run `buildstats.bash` against your TASSEL output directory; this is the main wrapper script, which calls the other scripts

# Description
"Failed samples (non-blank) are defined as those with less than 10% of the mean reads per sample coming from the lane on which they were sequenced" i.e.,
* [(Number of ‘good barcoded TASSEL 3 reads’ per barcoded sample) / ((Total reads per lane) / Number of Samples per lane)] * 100
* A good tag is defined as a read:
  * Matching the barcode + cut site remnant (for example: `CAGC` or `CTGC` for *ApeKI*)
  * Removing the barcode (leaving the cut site remnant and sequence)
  * Trimming the read to 64 bases
  *Lacking Ns
* The last two columns "PassFailPercentage" and "PassFail" in the CSV file are of interest.
