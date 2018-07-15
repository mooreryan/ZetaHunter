##ZetaHunter Example Datasets

The following example datasets are provided to demonstrate the proper use of ZetaHunter for **1)** the classification of **Zetaproteobacteria** small subunit ribosomal RNA (commonly 16S) gene sequences and **2)** the classification of 16S gene sequences from **other poorly-resolved taxa** using a custom database.

Navigate to the example dataset folder (```pwd``` should return ```~/software/ZetaHunter/example-datasets/Zetaproteobacteria_classification``` or similar based on where you installed ZetaHunter and which example folder you are exploring). Then, running the command for each example should create an outfolder identical to the folders found in ```EXAMPLE_OUT```. Each output folder within ```EXAMPLE_OUT``` contains the output from a run on the exact same dataset using ZetaHunter within a Docker image or from source ("ruby").

The input files (01\_SINA\_aligned\_16S\_infiles) for these example databases were prepared by submitting fasta files for alignment with the [SINA web aligner][web2]. It is critical to supply ZetaHunter with the full 50,000 bp ARB SILVA alignment, otherwise you will get an error message. If error messages persist, please contact us at [zetahunter.help@gmail.com](mailto:zetahunter.help@gmail.com) or submit an [issue](https://github.com/mooreryan/ZetaHunter/issues) on GitHub.

[web2]: https://www.arb-silva.de/aligner/

###1) Zetaproteobacteria classification

This example dataset includes data from Field et al. (2015; [doi:10.1038/ismej.2014.183][web1]). The dataset includes six different samples. Short 16S gene sequences in each sample are from 16S gene screening of a single cell sorting run while long 16S gene sequences come from the final sequenced genomes (often a complete 16S gene).

[web1]: https://www.nature.com/articles/ismej2014183

Zetaproteobacteria example dataset:

Docker: runtime 1 min 48 sec

```
run_zeta_hunter -i 01_SINA_aligned_16S_infiles/*.fasta -o ZH_OUT_docker_zeta_classification_example -t 4
```

Source installation: runtime 1 min 53 sec

```
ruby ~/software/ZetaHunter/zeta_hunter.rb -i 01_SINA_aligned_16S_infiles/*.fasta -o ZH_OUT_ruby_zeta_classification_example -t 4
```

###2) Classification of other poorly-resolved taxa

The manually curated database for this example dataset is based off of a defined taxonomic structure for the candidate phylum OP3 ("Omnitrophica") (Glöcker et al., 2010; [doi:10.1111/j.1462-2920.2010.02164.x][web3]. Glöckner et al. (2010) defined the taxonomy based on five stable phylogenetic divisions, which exist at a higher taxonomic level than a standard 97% identity OTU (minimum within taxa similarity = 80%). 

Two sample input files are given. In the first, we have provided the representative sequences used to test ZetaHunter in the documentation. This includes data from McAllister et al. (2015; [doi:10.1111/lno.10029][web4]). A single sample file contains all of the representative sequences for 97% similarity OTUs from the Cape Shores intertidal mixing zone beach aquifer.

In the second sample input file, we include all Omnitrophica/OP3 sequences in ARB SILVA (release 128) (Glöckner et al., 2017; [doi:10.1016/j.jbiotec.2017.06.1198][web5]). From the analysis of this file, we can classify all OP3 sequences into the proposed five-division taxonomy.

Please note that ZetaHunter can use both gzipped and uncompressed files. These example files are compressed for convenience.

[web3]: https://onlinelibrary.wiley.com/doi/abs/10.1111/j.1462-2920.2010.02164.x
[web4]: https://aslopubs.onlinelibrary.wiley.com/doi/abs/10.1002/lno.10029
[web5]: https://www.sciencedirect.com/science/article/pii/S0168165617314943?via%3Dihub

####Cape Shores OP3 classification

Docker: runtime 4 min 1 sec

```
run_zeta_hunter -i 01_SINA_aligned_16S_infiles/all_CapeShores_OP3_aligned.fa.gz -o ZH_OUT_docker_CapeShores_OP3_classification_example -t 4 -d 02_curated_database/op3_db_otu_info.txt -m 02_curated_database/op3_mask.fa.gz -b 02_curated_database/op3_db_seqs.fa.gz -u 80
```

Source installation: runtime 4 min 32 sec

```
ruby ~/software/ZetaHunter/zeta_hunter.rb -i 01_SINA_aligned_16S_infiles/all_CapeShores_OP3_aligned.fa.gz -o ZH_OUT_ruby_CapeShores_OP3_classification_example -t 4 -d 02_curated_database/op3_db_otu_info.txt -m 02_curated_database/op3_mask.fa.gz -b 02_curated_database/op3_db_seqs.fa.gz -u 80
```

####All SILVA release 128 OP3 classification

Docker: runtime 11 min 49 sec

```
run_zeta_hunter -i 01_SINA_aligned_16S_infiles/all_OP3_SILVA128_aligned.fa.gz -o ZH_OUT_docker_SILVA128_OP3_classification_example -t 4 -d 02_curated_database/op3_db_otu_info.txt -m 02_curated_database/op3_mask.fa.gz -b 02_curated_database/op3_db_seqs.fa.gz -u 80
```

Source installation: runtime 13 min 4 sec

```
ruby ~/software/ZetaHunter/zeta_hunter.rb -i 01_SINA_aligned_16S_infiles/all_OP3_SILVA128_aligned.fa.gz -o ZH_OUT_ruby_SILVA128_OP3_classification_example -t 4 -d 02_curated_database/op3_db_otu_info.txt -m 02_curated_database/op3_mask.fa.gz -b 02_curated_database/op3_db_seqs.fa.gz -u 80
```
Note: By skipping chimera checking, runtime for this sample file (using the source installation) dropped to 6 min 19 sec. If you would like to skip chimera checking pass the ```--no-check-chimeras``` option when running ZetaHunter.
