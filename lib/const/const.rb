require "abort_if"
require "os"
require_relative "../version"

module Const
  COPYRIGHT = "2016 Ryan Moore"
  CONTACT   = "moorer@udel.edu"
  WEBSITE   = "https://github.com/mooreryan/ZetaHunter"
  LICENSE   = "GPLv3"

  VERSION_BANNER = "  # Version: #{Object::ZetaHunter::VERSION}
  # Copyright #{COPYRIGHT}
  # Contact: #{CONTACT}
  # Website: #{WEBSITE}
  # License: #{LICENSE}"

  # directories
  this_dir          = File.dirname(__FILE__)
  PROJ_DIR          = File.absolute_path File.join this_dir, "..", ".."
  LIB_DIR           = File.join PROJ_DIR, "lib"
  ASSETS_DIR        = File.join PROJ_DIR, "assets"
  SORTMERNA_IDX_DIR = File.join ASSETS_DIR, "db_seqs_sortmerna_idx"
  TEST_DIR          = File.join PROJ_DIR, "test_files"
  TEST_OUTDIR       = File.join TEST_DIR, "full_and_part_output"
  # TEST_OUTDIR = "/Users/moorer/projects/ZetaHunter3000/test_files/zetas_arb-silva.de_2016-02-15_id318609/outdir"
  ENTROPY_DIR       = File.join ASSETS_DIR, "db_mask_entropy"

  if OS.mac?
    BIN_DIR = File.join PROJ_DIR, "bin", "mac"
  elsif OS.linux?
    BIN_DIR = File.join PROJ_DIR, "bin", "linux"
  else
    abort_if true, "OS is neither Mac or Linux...use the Docker " +
                   "image instead."
  end

  # binaries
  INDEXDB_RNA     = File.join BIN_DIR, "indexdb_rna"
  MOTHUR          = File.join BIN_DIR, "mothur"
  SORTMERNA       = File.join BIN_DIR, "sortmerna"

  # assets
  GOLD_ALN      = File.join ASSETS_DIR, "silva.gold.align"
  SILVA_FREQ    = File.join ASSETS_DIR, "silva.bacteria.freq"
  SILVA_QUAN    = File.join ASSETS_DIR, "silva.bacteria.pintail.quan"
  DB_OTU_INFO   = File.join ASSETS_DIR, "db_otu_info.txt"
  DB_SEQS       = File.join ASSETS_DIR, "db_seqs.fa"
  DB_SEQS_UNALN = File.join ASSETS_DIR, "db_seqs.unaln.fa"
  MASK          = File.join ASSETS_DIR, "mask.fa"
  OUTGROUPS     = File.join ASSETS_DIR, "outgroup_names.txt"
  ENTROPY       = File.join ENTROPY_DIR, "entropy.txt"
  SORTMERNA_IDX = File.join SORTMERNA_IDX_DIR, "db_seqs.unaln.idx"
  # test files
  TEST_ALN = File.join TEST_DIR, "full_and_part.fa"
  # TEST_ALN = "/Users/moorer/projects/ZetaHunter3000/test_files/zetas_arb-silva.de_2016-02-15_id318609/zetas.arb-silva.de_2016-02-15_id318609.fasta"

  # info
  SILVA_ALN_LEN  = 50000
  CLUSTER_CUTOFF = 0.03
  MASK_LEN       = 1282

  # mim qcov for sort me rna calls
  MIN_QCOV = 0.75

end
