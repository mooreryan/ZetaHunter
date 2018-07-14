# ZetaHunter

## Citation

If you find ZetaHunter useful in your research, please cite the [bioRxiv preprint](https://www.biorxiv.org/content/early/2018/07/03/359620):

```
McAllister, SM, RM Moore, and CS Chan. 2018. ZetaHunter: a reproducible taxonomic classification tool for tracking the ecology of the Zetaproteobacteria and other poorly-resolved taxa. bioRxiv 359620; doi: https://doi.org/10.1101/359620
```

## Wiki

Check the [ZetaHunter Wiki](https://github.com/mooreryan/ZetaHunter/wiki) for
more info!  There you will find help on how to install and run ZetaHunter, as well as a lot more details about how ZetaHunter works.

## Overview

ZetaHunter is a command line script designed to assign user-supplied
small subunit ribosomal RNA (SSU rRNA) gene sequences to OTUs defined
by a reference sequence database.

By default, ZetaHunter uses a curated database of full-length,
non-chimeric, Zetaproteobacteria SSU rRNA gene sequences derived from
arb SILVA (release 128) and Zetaproteobacteria genomes from JGI's
Integrated Microbial Genomes (IMG). OTU definitions are the same as
those suggested by McAllister et al. (2011) at 97% identity, with
novel OTUs discovered since that publication named ZetaOTU29 and
higher (curated OTUs only). Infiles aligned by the arb SILVA SINA web
aligner are masked using the same 1282 bp mask used in McAllister et
al. (2011) to obtain reproducible OTU calls through closed reference
OTU binning. User sequences that represent novel Zetaproteobacteria
OTUs are de novo binned into NewZetaOTUs, numbered by abundance.

OTU network analysis is a simple way to visualize the connectivity of
OTUs within a sample or environment type. ZetaHunter will output edge
and node tab-delimited files for import into cytoscape. The node file
contains the abundance information for each node. The edge file lists
OTUs that are found within the same sample (node1, node2, sample), thus
allowing for visualization. Note: Samples with only one ZetaOTU will contain
a self referential edge. Otherwise, only non-self connections are shown.

ZetaHunter also supports user-provided curated OTU databases for
sequence OTU binning of any SINA-aligned SSU rRNA sequences.

## Features

1. Stable SSU rRNA gene OTU binning to a curated database
2. Supports import of multiple files for easy comparison of NewZetaOTUs across samples
3. Database and sequence mask management options
4. Multi-threaded processing
5. Chimera checking
6. Flags for sequences not related to the curated database (i.e. not Zetaproteobacteria)
7. Cytoscape-compatible output file for OTU network analysis