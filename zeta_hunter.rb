# Copyright 2016 - 2018 Ryan Moore
# Contact: moorer@udel.edu
#
# This file is part of ZetaHunter.
#
# ZetaHunter is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ZetaHunter is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ZetaHunter.  If not, see <http://www.gnu.org/licenses/>.

require_relative File.join "lib", "lib_helper.rb"

# Monkey patch of Tmpname::make_tmpname.
#
# Only lines with a comment have been changed, the rest is the same.
#
# The reason for this is that mothur doesn't like '-' characters in
# the paths of anything.
class Dir
  module Tmpname
    module_function

    def make_tmpname((prefix, suffix), n)
      prefix = (String.try_convert(prefix) or
                raise ArgumentError, "unexpected prefix: #{prefix.inspect}")
      suffix &&= (String.try_convert(suffix) or
                  raise ArgumentError, "unexpected suffix: #{suffix.inspect}")
      t = Time.now.strftime("%Y%m%d")

      # Here we replace - with _
      path = "#{prefix}#{t}_#{$$}_#{rand(0x100000000).to_s(36)}".dup

      # And here as well
      path << "_#{n}" if n

      path << suffix if suffix
      path
    end
  end
end

include Const
include Utils

Process.extend CoreExtensions::Process
Time.extend CoreExtensions::Time
File.extend CoreExtensions::File
Hash.include CoreExtensions::Hash
Dir.extend CoreExtensions::Dir

THIS_D = File.dirname(__FILE__)
ZH_PWD_DIR = Dir.pwd

gunzip = Utils.which_gunzip

argv_copy = ARGV.dup

require "optimist"

opts = Optimist.options do
  version VERSION_BANNER

  banner <<-EOS

#{VERSION_BANNER}

  For information on running ZetaHunter please visit the ZetaHunter
  website (https://github.com/mooreryan/ZetaHunter).  There you will
  find the ZetaHunter Wiki with lots of information on how to run
  ZetaHunter, the command line options, and more
  (https://github.com/mooreryan/ZetaHunter/wiki).

  Also, we have repository with some example datasets and step-by-step
  instructions on analyzing data with ZetaHunter
  (https://github.com/mooreryan/ZetaHunter_examples).

  The most common options for running ZetaHunter are these:

    -i, --inaln (path to the input sequence alignments)
    -o, --outdir (path where ZetaHunter will dump its output)
    -t, --threads (number of processors to use)

  In most cases, these three options will be all you need.

  Options:
  EOS

  opt(:inaln,
      "Input alignment(s)",
      type: :strings)

  opt(:outdir,
      "Directory for output",
      type: :string)

  opt(:threads,
      "Number of processors to use",
      type: :integer,
      default: 2)

  opt(:db_otu_info,
      "Database OTU info file name",
      type: :string,
      default: DB_OTU_INFO)

  opt(:mask, "Fasta file with the mask",
      type: :string,
      default: MASK)

  opt(:db_seqs, "Fasta file with aligned DB seqs",
      type: :string,
      default: DB_SEQS)

  opt(:mothur, "The mothur executable",
      type: :string,
      default: MOTHUR,
      short: "-r")

  opt(:sortmerna, "The SortMeRNA executable",
      type: :string,
      default: SORTMERNA)

  opt(:indexdb_rna, "The SortMeRNA idnexdb_rna executable",
      type: :string,
      default: INDEXDB_RNA)

  opt(:cluster_method, "Either furthest, average, or nearest",
      type: :string,
      default: "average")

  opt(:otu_percent, "OTU similarity percentage",
      type: :int,
      default: 97)

  opt(:check_chimeras, "Flag to check chimeras", short: "-k",
      default: true)

  opt(:base, "Base name for output files", default: "ZH_#{START_TIME}")

  opt(:debug, "Debug mode, don't delete tmp files or clean up the working dir (the out dir will be empty)")
end

THREADS        = opts[:threads]
MOTHUR         = opts[:mothur]
INDEXDB_RNA    = opts[:indexdb_rna]
SORTME_RNA     = opts[:sortmerna]
CLUSTER_METHOD = opts[:cluster_method]
BASE           = opts[:base]

if opts[:otu_percent] < 0 || opts[:otu_percent] > 99
  Optimist.die :otu_percent, "OTU similarity must be from 0 to 99"
end

OTU_DIST = 100 - opts[:otu_percent]

if opts[:inaln].nil?
  Optimist.die :inaln, "Specify an input alignment"
end

if opts[:outdir].nil?
  Optimist.die :outdir, "Specify an output directory"
end

WORKING_D = Dir.mktmpdir

TMP_OUT_D   = File.join WORKING_D, "tmp"
DANGEROUS_D = File.join WORKING_D, "dangerous_seqs"
OTU_CALLS_D = File.join WORKING_D, "otu_calls"
LOG_D       = File.join WORKING_D, "log"
MISC_DIR    = File.join WORKING_D, "misc"
BIOM_D      = File.join WORKING_D, "biom"
CHIMERA_D   = File.join DANGEROUS_D, "chimera_details"
CYTOSCAPE_D = File.join WORKING_D, "cytoscape"

FINAL_OUT_D = opts[:outdir]

######################################################################
# set up logger
###############

if File.writable?(ZH_PWD_DIR)
  ZH_LOG = File.join ZH_PWD_DIR, "#{BASE}.log.zh.txt"
elsif File.writable?(THIS_D)
  ZH_LOG = File.join THIS_D, "#{BASE}.log.zh.txt"
else
  require "tempfile"
  zh_log_f = Tempfile.new "zh_log"
  ZH_LOG = zh_log_f.path
end
ZH_LOG_FINAL = File.join LOG_D, File.basename(ZH_LOG)
MOTHUR_LOG   = File.join LOG_D, "#{BASE}.log.mothur.txt"

logger = Log4r::Logger.new "ZH Log"

stderr_outputter  = Log4r::StderrOutputter.new("stderr")
file_outputter    = Log4r::FileOutputter.new("file", filename: ZH_LOG)
pattern_formatter =
  Log4r::PatternFormatter.new(pattern: "%-5l -- [%d] -- %M ",
                              date_pattern: "%F %T.%L")

stderr_outputter.formatter = pattern_formatter
file_outputter.formatter = pattern_formatter

logger.outputters << stderr_outputter
logger.outputters << file_outputter

AbortIf::Abi.set_logger logger

# Check for correct version of parse fasta
begin
  FastaFile
rescue NameError => e
  AbortIf::Abi.logger.fatal do
    "Uninitialized constant: FastaFile. ZetaHunter requires " +
      "parse_fasta library version >= 1.8, but <= 1.9.1. " +
      "Do you have version 2 installed? Run this command " +
      "(without the quotes) to find out: " +
      "'gem list | grep parse_fasta'."
  end

  abort
end

AbortIf::Abi.logger.debug do
  "Version: #{ZetaHunter::VERSION}, " +
    "Copyright: #{COPYRIGHT}, " +
    "Contact: #{CONTACT}, " +
    "Website: #{WEBSITE}, " +
    "License: #{LICENSE}"
end

AbortIf::Abi.logger.info { "Temporary log file location: #{ZH_LOG}. If " +
                           "ZetaHunter fails to complete, the log will be here." }

AbortIf::Abi.logger.debug { "ARGV: #{argv_copy.inspect}" }
AbortIf::Abi.logger.debug { "Command line opts: #{opts.inspect}" }

###############
# set up logger
######################################################################

opts[:inaln].each do |fname|
  AbortIf::Abi.abort_unless_file_exists fname
end

AbortIf::Abi.abort_unless_file_exists opts[:db_otu_info]
AbortIf::Abi.abort_unless_file_exists opts[:mask]
AbortIf::Abi.abort_unless_file_exists opts[:db_seqs]
AbortIf::Abi.abort_unless_file_exists MOTHUR
AbortIf::Abi.abort_unless_file_exists SORTME_RNA
AbortIf::Abi.abort_unless_file_exists INDEXDB_RNA

msg = "--threads must be > 0, was #{THREADS}"
AbortIf::Abi.abort_unless THREADS > 0, msg

check = %w[furthest average nearest].one? do |opt|
  CLUSTER_METHOD == opt
end

msg = "--cluster-method must be one of furthest, average or nearest"
AbortIf::Abi.abort_unless check, msg


######################################################################
# clean file names for mothur
#############################

# opts[:inaln] = opts[:inaln].map { |fname| File.clean_and_copy fname }

# opts[:db_otu_info] = File.clean_and_copy opts[:db_otu_info]
# opts[:mask]        = File.clean_and_copy opts[:mask]
# opts[:db_seqs]     = File.clean_and_copy opts[:db_seqs]

# opts[:outdir] = File.clean_fname opts[:outdir]

def simple_clean_and_copy orig_fname, new_dir
  basename = File.basename orig_fname
  clean_basename = File.clean_fname basename

  # Try to make the dir if it isn't made yet
  begin
    FileUtils.mkdir_p new_dir
  rescue Errno::EEXIST => e
    AbortIf::Abi.logger.debug { "#{new_dir} already exists. No action taken" }
  end

  new_fname = File.join new_dir, clean_basename

  FileUtils.cp orig_fname, new_fname

  new_fname
end

# The following files will be used in mother and need to have clean
# fnames

clean_inaln_fnames =
  opts[:inaln].map { |fname| simple_clean_and_copy fname, TMP_OUT_D }

clean_db_otu_info_fname = simple_clean_and_copy opts[:db_otu_info],
                                                WORKING_D
clean_mask_fname        = simple_clean_and_copy opts[:mask],
                                                WORKING_D
clean_db_seqs_fname     = simple_clean_and_copy opts[:db_seqs],
                                                WORKING_D

#############################
# clean file names for mothur
######################################################################

Time.time_it("Create needed directories", AbortIf::Abi.logger) do
  Utils.create_needed_dirs
end

# This is way up here because it should note the ORIGINAL file names
# with the sample
SAMPLE_TO_FNAME_F =
  File.join MISC_DIR,
            "#{BASE}.sample_id_to_fname.txt"

Time.time_it("Write sample to file name map", AbortIf::Abi.logger) do
  Utils.write_sample_to_file_name_map SAMPLE_TO_FNAME_F, clean_inaln_fnames
end

clean_inaln_ungzip_fnames = nil
Time.time_it("Unzip if needed", AbortIf::Abi.logger) do
  clean_inaln_ungzip_fnames = Utils.ungzip_if_needed clean_inaln_fnames, TMP_OUT_D
end

CHIMERA_DETAILS =
  File.join WORKING_D, "*.{pintail,uchime,slayer}.*"

CLUSTER_ME_F = File.join TMP_OUT_D, "cluster_me.fa"
CLUSTER_ME_DIST_F = File.join TMP_OUT_D, "cluster_me.phylip.dist"

METHOD = get_cluster_method CLUSTER_METHOD

CLUSTER_ME_LIST_F =
  File.join TMP_OUT_D, "cluster_me.phylip.#{METHOD}.list"
OTU_F_BASENAME =
  File.join TMP_OUT_D, "cluster_me.phylip.#{METHOD}.0"

otu_file = ""

DENOVO_OTUS_F =
  File.join OTU_CALLS_D, "#{BASE}.otu_calls.denovo.txt"

FINAL_OTU_CALLS_F =
  File.join OTU_CALLS_D, "#{BASE}.otu_calls.final.txt"

DISTANCE_BASED_OTUS_F =
  File.join OTU_CALLS_D, "#{BASE}.otu_calls.closed_ref.txt"

BIOM_F =
  File.join BIOM_D, "#{BASE}.biom.txt"

CHIMERIC_SEQS_F =
  File.join DANGEROUS_D, "#{BASE}.dangerous_seqs.chimeras.txt"

INPUT_UNALN_F = File.join TMP_OUT_D, "#{BASE}.unaln.fa"

sortme_blast_f =
  File.join WORKING_D, "#{BASE}.unlan.sortme_blast"

CLOSEST_SEQS_F =
  File.join MISC_DIR, "#{BASE}.closest_db_seqs.txt"

# for SortMeRNA
DB_SEQS_UNALN = File.join TMP_OUT_D, "db_seqs.unaln.fa"
SORTMERNA_IDX = File.join TMP_OUT_D, "db_seqs.unaln.idx"

NODES_F = File.join CYTOSCAPE_D, "#{BASE}.cytoscape_node_table.txt"
EDGES_F = File.join CYTOSCAPE_D, "#{BASE}.cytoscape_network_edges.txt"


# containers

chimeric_ids             = {}
closed_ref_otus          = {}
closest_to_outgroups     = []
cluster_these_user_seqs  = {}
db_otu_info              = {}
db_seq_ids               = Set.new
db_seqs                  = {}
entropy                  = []
gap_posns                = []
input_ids                = Set.new
input_seqs               = {}
mask                     = []
masked_input_seq_entropy = {}
outgroup_names           = Set.new
otu_info                 = []
total_entropy            = 0

######################################################################
# process user input alignment
##############################

Time.time_it("Process input data", AbortIf::Abi.logger) do
  Utils.process_input_alns files: clean_inaln_ungzip_fnames,
                           seq_ids: input_ids,
                           seqs: input_seqs,
                           gap_posns: gap_posns
end

##############################
# process user input alignment
######################################################################

######################################################################
# read provided info
####################

Time.time_it("Read entropy info", AbortIf::Abi.logger) do
  entropy = File.read_entropy ENTROPY
  total_entropy = entropy.reduce(:+)
end

Time.time_it("Read db OTU metadata", AbortIf::Abi.logger) do
  db_otu_info = read_otu_metadata clean_db_otu_info_fname
end

Time.time_it("Read mask info", AbortIf::Abi.logger) do
  mask = read_mask clean_mask_fname
end

Time.time_it("Update shared gap posns with db seqs", AbortIf::Abi.logger) do
  Utils.process_input_aln file: clean_db_seqs_fname,
                    seq_ids: db_seq_ids,
                    seqs: db_seqs,
                    gap_posns: gap_posns
end

# Read both the clean ID and the orig ID in
Time.time_it("Read outgroups", AbortIf::Abi.logger) do
  lines = []
  Object::File.open(OUTGROUPS, "rt").each_line do |line|
    lines << line.chomp
    lines << clean(line.chomp)
  end

  outgroup_names = Set.new lines
end

####################
# read provided info
######################################################################

######################################################################
# degap & mask
##############

shared_gap_posns = gap_posns.reduce(:&)

Time.time_it("Degap and mask", AbortIf::Abi.logger) do
  update_with_degapped_and_mask input_seqs, mask, shared_gap_posns
  update_with_degapped_and_mask db_seqs, mask, shared_gap_posns
end

##############
# degap & mask
######################################################################

######################################################################
# entropy for masked seqs
#########################

Time.time_it("Get entropy for masked user seqs", AbortIf::Abi.logger) do
  masked_input_seq_entropy = Utils.get_entropy_for_seqs entropy, input_seqs
end

#########################
# entropy for masked seqs
######################################################################


######################################################################
# slay the chimeras
###################
if opts[:check_chimeras]

  ####################################################################
  # unzip the silva gold aln
  ##########################

  SILVA_GOLD_ALN = Utils.unzip_silva_gold_aln TMP_OUT_D

  ##########################
  # unzip the silva gold aln
  ####################################################################

  Time.time_it("Uchime", AbortIf::Abi.logger) do
    Utils.run_uchime clean_inaln_ungzip_fnames
  end

  # There will be one uchime_ids file per clean_inaln_ungzip_fnames fname
  Time.time_it("Read uchime chimeras", AbortIf::Abi.logger) do
    Utils.read_uchime_chimeras clean_inaln_ungzip_fnames, chimeric_ids
  end

  Time.time_it("Write chimeric seqs", AbortIf::Abi.logger) do
    Utils.write_chimeric_seqs chimeric_ids, CHIMERIC_SEQS_F, input_seqs
  end
end

###################
# slay the chimeras
######################################################################

######################################################################
# SortMeRNA distance based closed reference OTU calls
#####################################################


Time.time_it("Unalign DB seqs if needed", AbortIf::Abi.logger) do
  Utils.unalign_seqs_from_file clean_db_seqs_fname, DB_SEQS_UNALN
end

Time.time_it("Unalign input seqs", AbortIf::Abi.logger) do
  Utils.unalign_seqs_from_input_seqs input_seqs,INPUT_UNALN_F
end

# TODO only do this if it doesn't already exist
Time.time_it("Build SortMeRNA index", AbortIf::Abi.logger) do
  Utils.build_sortmerna_idx
end

Time.time_it("SortMeRNA", AbortIf::Abi.logger) do
  sortme_blast_f = Utils.run_sortmerna INPUT_UNALN_F, sortme_blast_f
end

# TODO double check that this doesn't assume one hit per query
Time.time_it("Read SortMeRNA blast", AbortIf::Abi.logger) do
  closed_ref_otus = Utils.read_sortme_blast sortme_blast_f
end

Time.time_it("Write closest ref seqs and OTU calls", AbortIf::Abi.logger) do
  closest_to_outgroups, cluster_these_user_seqs =
                        Utils.write_closest_ref_seqs_and_otu_calls(CLOSEST_SEQS_F,
                                                                   closed_ref_otus,
                                                                   masked_input_seq_entropy,
                                                                   input_seqs,
                                                                   db_otu_info,
                                                                   outgroup_names)
end

#####################################################
# SortMeRNA distance based closed reference OTU calls
######################################################################


######################################################################
# cluster
#########

run = true
Time.time_it("Write masked, combined fasta", AbortIf::Abi.logger) do
  Utils.write_cluster_me_file CLUSTER_ME_F, cluster_these_user_seqs, db_seqs
end

Time.time_it("Distance", AbortIf::Abi.logger) do
  Utils.run_mothur_distance CLUSTER_ME_F
end

Time.time_it("Cluster", AbortIf::Abi.logger) do
  Utils.run_mothur_cluster CLUSTER_ME_DIST_F
end

Time.time_it("Get OTU list", AbortIf::Abi.logger) do
  Utils.run_mothur_get_otu_list CLUSTER_ME_LIST_F
end

#########
# cluster
######################################################################

######################################################################
# assigned detailed OTU info
############################

Time.time_it("Find OTU file", AbortIf::Abi.logger) do
  otu_file = Utils.find_otu_file OTU_F_BASENAME, OTU_DIST
end

Time.time_it("Assign de novo OTUs", AbortIf::Abi.logger) do
  Utils.assign_denovo_otus otu_file,
                           db_otu_info,
                           input_ids,
                           input_seqs,
                           closest_to_outgroups,
                           masked_input_seq_entropy,
                           closed_ref_otus
end

Time.time_it("Write final OTU calls", AbortIf::Abi.logger) do
  Utils.write_final_otu_calls
end

############################
# assigned detailed OTU info
######################################################################

######################################################################
# write biom file
#################

Time.time_it("Write biom file", AbortIf::Abi.logger) do
  Utils.write_biom_file clean_inaln_ungzip_fnames
end

#################
# write biom file
######################################################################

######################################################################
# write cytoscape files
#######################

Time.time_it("Write cytoscape files", AbortIf::Abi.logger) do
  Utils.write_cytoscape_files
end

#######################
# write cytoscape files
######################################################################


######################################################################
# clean up
##########

Time.time_it("Clean up", AbortIf::Abi.logger) do
  unless opts[:debug]
    # Delete these files specifically
    files_to_delete = [clean_inaln_fnames,
                       clean_inaln_ungzip_fnames,
                       clean_db_otu_info_fname,
                       clean_mask_fname,
                       clean_db_seqs_fname].flatten.uniq

    files_to_delete.each do |fname|
      begin
        FileUtils.rm fname
      rescue SystemCallError => e
        AbortIf::Abi.logger.warn do
          "Could not delete '#{fname}'. " +
            "This likely is not an issue, but your outdir might " +
            "be messy. Error: #{e.inspect}"
        end
      end
    end

    Utils.clean_up sortme_blast_f, opts[:debug]
  end
end

##########
# clean up
######################################################################

def to_outdir fname
  fname.sub WORKING_D, FINAL_OUT_D
end

AbortIf::Abi.logger.info { "FINAL FILE OUTPUTS" }

AbortIf::Abi.logger.info { "Cytoscape node table: #{to_outdir NODES_F}" }
AbortIf::Abi.logger.info { "Cytoscape edge table: #{to_outdir EDGES_F}" }

AbortIf::Abi.logger.info { "Biom file:            #{to_outdir BIOM_F}" }

AbortIf::Abi.logger.info { "Final OTUs:           #{to_outdir FINAL_OTU_CALLS_F}" }
AbortIf::Abi.logger.info { "Denovo OTUs:          #{to_outdir DENOVO_OTUS_F}" }
AbortIf::Abi.logger.info { "Closed ref OTUs:      #{to_outdir DISTANCE_BASED_OTUS_F}" }

AbortIf::Abi.logger.info { "SortMeRNA output:     #{to_outdir sortme_blast_f}" }
AbortIf::Abi.logger.info { "Closest DB seqs:      #{to_outdir CLOSEST_SEQS_F}" }

AbortIf::Abi.logger.info { "Chimeras:             #{to_outdir CHIMERIC_SEQS_F}" }

AbortIf::Abi.logger.info { "Sample to fname map:  #{to_outdir SAMPLE_TO_FNAME_F}" }

AbortIf::Abi.logger.info { "ZetaHunter log:       #{to_outdir ZH_LOG_FINAL}" }
AbortIf::Abi.logger.info { "Mothur log:           #{to_outdir MOTHUR_LOG}" }

STDERR.puts Const::LOGO
