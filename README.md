# ZetaHunter

[![Build Status](https://travis-ci.org/mooreryan/ZetaHunter.svg?branch=master)](https://travis-ci.org/mooreryan/ZetaHunter)

## Citation

If you find ZetaHunter useful in your research, please cite the [ZetaHunter manuscript](http://dx.doi.org/10.1128/MRA.00932-18).

```
McAllister, S. M., Moore, R. M., and Chan, C. S. ZetaHunter, a Reproducible Taxonomic Classification Tool for Tracking the Ecology of the Zetaproteobacteria and Other Poorly Resolved Taxa. Aug 2018, 7 (7) e00932-18; DOI: 10.1128/MRA.00932-18.
```

Or you can download the citation and import it into your favorite reference manager!

- [BibTeX](https://raw.githubusercontent.com/mooreryan/ZetaHunter/master/citation/zeta_hunter.bib)
- [EndNote](https://raw.githubusercontent.com/mooreryan/ZetaHunter/master/citation/zeta_hunter.enw)
- [RIS](https://raw.githubusercontent.com/mooreryan/ZetaHunter/master/citation/zeta_hunter.ris)

## Wiki

Check the [ZetaHunter Wiki](https://github.com/mooreryan/ZetaHunter/wiki) for
more info!  There you will find help on how to install and run ZetaHunter, as well as a lot more details about how ZetaHunter works.

## Example datasets

Check out [ZetaHunter example datasets](https://github.com/mooreryan/ZetaHunter_examples) if you would like to check out some sample data and output from ZetaHunter.  There, you will also find a step by step guide to generating the expected output. You can also find the same sample input and curated database files [here](https://github.com/mooreryan/ZetaHunter/tree/master/example_data).

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

## Help

If you run into problems or need help with using ZetaHunter, please email us at: [zetahunter.help@gmail.com](mailto:zetahunter.help@gmail.com)
