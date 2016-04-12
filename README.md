# ZetaHunter #

## Dependencies ##

### External programs ###

#### Mothur ####

[Mothur](http://mothur.org/)

Please cite

    Schloss, P.D., et al., Introducing mothur: Open-source, platform-independent, community-supported software for describing and comparing microbial communities. Appl Environ Microbiol, 2009. 75(23):7537-41.

#### SortMeRNA ####

[SortMeRNA](http://bioinfo.lifl.fr/RNA/sortmerna/)

Please cite

    Kopylova E., Noé L. and Touzet H., "SortMeRNA: Fast and accurate filtering of ribosomal RNAs in metatranscriptomic data", Bioinformatics (2012), doi: 10.1093/bioinformatics/bts611.

### Gems ###

See `Gemfile`

## Assets ##

`silva.gold.align.gz` is from http://www.mothur.org/wiki/Silva_reference_files

**NOTE**: This file will be temporarily unzipped (requires 247mb of
  hard drive space) if chimera checking is turned on.

### OTU Metadata ###

Lines beginning with `#` are considered comments.

## Gap positions ##

`base.match /[^ACTGUN]/i`

## Sequence headers ##

The headers are split on " " characters and the first part of that is
taken to be the sequence ID and must be unique.

## TODO ##

- names/counts file for cluster step
- try symlink instead of copying to sanitize files names

- mothur errors should terminate program

- check ALL infiles

## Entropy ##

The entropy file needs to be rebuilt each time `db_seqs.fa` is updated.
