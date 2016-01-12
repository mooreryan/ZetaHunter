module Const
  # directories
  this_dir = File.dirname(__FILE__)
  PROJ_DIR = File.absolute_path File.join this_dir, "..", ".."
  BIN_DIR = File.join PROJ_DIR, "bin"
  LIB_DIR = File.join PROJ_DIR, "lib"
  ASSETS_DIR = File.join PROJ_DIR, "assets"
  TEST_DIR = File.join "test_files"
  TEST_OUTDIR = File.join TEST_DIR, "output"

  # binaries
  MOTHUR = File.join BIN_DIR, "osx", "mothur", "mothur"
  REMOVE_ALL_GAPS = File.join BIN_DIR, "remove_gaps.rb"

  # assets
  GOLD_ALN = File.join ASSETS_DIR, "silva.gold.align"
  SILVA_FREQ = File.join ASSETS_DIR, "silva.bacteria.freq"
  SILVA_QUAN = File.join ASSETS_DIR, "silva.bacteria.pintail.quan"

  # test files
  TEST_ALN = File.join TEST_DIR, "full_and_part.fa"

  # info
  SILVA_ALN_LEN = 50000
end
