require "abort_if"
require "os"
require_relative "../version"
require_relative "../abort_if/abort_if"

module Const
  ####################################################################
  # program info
  ##############

  COPYRIGHT = "2016 Ryan Moore"
  CONTACT   = "moorer@udel.edu"
  WEBSITE   = "https://github.com/mooreryan/ZetaHunter"
  LICENSE   = "GPLv3"

  VERSION_BANNER = "  # Version: #{Object::ZetaHunter::VERSION}
  # Copyright #{COPYRIGHT}
  # Contact: #{CONTACT}
  # Website: #{WEBSITE}
  # License: #{LICENSE}"

  ##############
  # program info
  ####################################################################

  ####################################################################
  # directories
  #############

  # provided by ZH
  this_dir    = File.dirname(__FILE__)
  PROJ_DIR    = File.absolute_path File.join this_dir, "..", ".."
  LIB_DIR     = File.join PROJ_DIR, "lib"
  ASSETS_DIR  = File.join PROJ_DIR, "assets"
  ENTROPY_DIR = File.join ASSETS_DIR, "db_mask_entropy"

  if OS.mac?
    BIN_DIR = File.join PROJ_DIR, "bin", "mac"
  elsif OS.linux?
    BIN_DIR = File.join PROJ_DIR, "bin", "linux"
  else
    Abi.abort_if true, "OS is neither Mac or Linux...use the Docker " +
                       "image instead."
  end

  #############
  # directories
  ####################################################################

  ####################################################################
  # assets
  ########

  # provided with ZH
  SILVA_GOLD_ALN_GZ = File.join ASSETS_DIR, "silva.gold.align.gz"
  SILVA_FREQ        = File.join ASSETS_DIR, "silva.bacteria.freq"
  SILVA_QUAN        = File.join ASSETS_DIR, "silva.bacteria.pintail.quan"
  DB_OTU_INFO       = File.join ASSETS_DIR, "db_otu_info.txt"
  DB_SEQS           = File.join ASSETS_DIR, "db_seqs.fa.gz"
  MASK              = File.join ASSETS_DIR, "mask.fa.gz"
  OUTGROUPS         = File.join ASSETS_DIR, "outgroup_names.txt"

  # this needs to be manually updated each time the db_seqs database
  # is updated. It is the positional entropy in the mask for all Zetas
  # in the db_seqs database (not counting outgroups)
  ENTROPY       = File.join ENTROPY_DIR, "entropy.txt"

  ########
  # assets
  ####################################################################

  ####################################################################
  # binaries
  ##########

  # provided with ZH
  INDEXDB_RNA = File.join BIN_DIR, "indexdb_rna"
  MOTHUR      = File.join BIN_DIR, "mothur"
  SORTMERNA   = File.join BIN_DIR, "sortmerna"

  ##########
  # binaries
  ####################################################################

  ####################################################################
  # test files
  ############

  TEST_DIR    = File.join PROJ_DIR, "test_files"
  TEST_OUTDIR = File.join TEST_DIR, "full_and_part_output"
  TEST_ALN    = File.join TEST_DIR, "full_and_part.fa.gz"

  # TEST_OUTDIR = "/Users/moorer/projects/ZetaHunter3000/test_files/" +
  #               "zetas_arb-silva.de_2016-02-15_id318609/outdir"
  # TEST_ALN = "/Users/moorer/projects/ZetaHunter3000/test_files/" +
  #            "zetas_arb-silva.de_2016-02-15_id318609/zetas.arb-" +
  #            "silva.de_2016-02-15_id318609.fasta"

  ############
  # test files
  ####################################################################

  ####################################################################
  # constants
  ###########

  SILVA_ALN_LEN  = 50000
  CLUSTER_CUTOFF = 0.03
  MASK_LEN       = 1282

  # mim qcov for sort me rna calls
  MIN_QCOV = 0.90

  START_TIME = Time.now.strftime("%Y_%m_%d_%H_%M")

  ###########
  # constants
  ####################################################################
end
