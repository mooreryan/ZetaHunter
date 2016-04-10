# ZetaHunter #

## Dependencies ##

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
