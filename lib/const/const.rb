module Const
  # directories
  this_dir = File.dirname(__FILE__)
  PROJ_DIR = File.absolute_path File.join this_dir, "..", ".."
  BIN_DIR = File.join PROJ_DIR, "bin"
  LIB_DIR = File.join PROJ_DIR, "lib"
  ASSETS_DIR = File.join PROJ_DIR, "assets"
  TEST_DIR = File.join PROJ_DIR, "test_files"
  TEST_OUTDIR = File.join TEST_DIR, "full_and_part_output"
  # TEST_OUTDIR = "/Users/moorer/projects/ZetaHunter3000/test_files/zetas_arb-silva.de_2016-02-15_id318609/outdir"
  ENTROPY_DIR = File.join ASSETS_DIR, "db_mask_entropy"

  # binaries
  MOTHUR = File.join BIN_DIR, "osx", "mothur", "mothur"
  REMOVE_ALL_GAPS = File.join BIN_DIR, "remove_gaps.rb"

  # assets
  GOLD_ALN = File.join ASSETS_DIR, "silva.gold.align"
  SILVA_FREQ = File.join ASSETS_DIR, "silva.bacteria.freq"
  SILVA_QUAN = File.join ASSETS_DIR, "silva.bacteria.pintail.quan"
  DB_OTU_INFO = File.join ASSETS_DIR, "db_otu_info.txt"
  DB_SEQS = File.join ASSETS_DIR, "db_seqs.fa"
  MASK = File.join ASSETS_DIR, "mask.fa"
  OUTGROUPS = File.join ASSETS_DIR, "outgroup_names.txt"
  ENTROPY = File.join ENTROPY_DIR, "entropy.txt"

  # test files
  TEST_ALN = File.join TEST_DIR, "full_and_part.fa"
  # TEST_ALN = "/Users/moorer/projects/ZetaHunter3000/test_files/zetas_arb-silva.de_2016-02-15_id318609/zetas.arb-silva.de_2016-02-15_id318609.fasta"

  # info
  SILVA_ALN_LEN = 50000
  CLUSTER_CUTOFF = 0.03
  MASK_LEN = 1282

end
