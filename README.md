# LalaTeehee3000 #

## Dependencies ##

### Gems ###

See `Gemfile`

## Assets ##

`silva.gold.align` is from http://www.mothur.org/wiki/Silva_reference_files

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
- change the mothur short param from `-h` to something else

- avg neigh with closest distance to break ties
- avg neigh with dist weighted abund to break ties
- furthest neigh
- no clustering at all, just distance
- one at a time vs jumble

- mothur errors should terminate program
- clean up the mothur logfiles

## Entropy ##

The entropy file
