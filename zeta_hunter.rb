require_relative File.join "lib", "lib_helper.rb"

include Const
include Utils
#include Assert

Process.extend CoreExtensions::Process
Time.extend CoreExtensions::Time
File.extend CoreExtensions::File
Hash.include CoreExtensions::Hash

this_dir = File.dirname(__FILE__)

require "trollop"

opts = Trollop.options do
  version VERSION_BANNER

  banner <<-EOS

#{VERSION_BANNER}

  Hunt them Zetas!

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

  opt(:check_chimeras, "Flag to check chimeras", short: "-k",
      default: true)

  opt(:force, "Force overwriting of out directory")

  opt(:base, "Base name for output files", default: "ZH_#{START_TIME}")
end

if opts[:inaln].nil?
  Trollop.die :inaln, "Specify an input alignment"
end

if opts[:outdir].nil?
  Trollop.die :outdir, "Specify an output directory"
end

outdir_tmp    = File.join opts[:outdir], "tmp"
dangerous_dir = File.join opts[:outdir], "dangerous_seqs"
otu_calls_dir = File.join opts[:outdir], "otu_calls"
log_dir       = File.join opts[:outdir], "log"
misc_dir      = File.join opts[:outdir], "misc"
biom_dir      = File.join opts[:outdir], "biom"
chimera_dir   = File.join dangerous_dir, "chimera_details"

######################################################################
# set up logger
###############

if File.writable?(Dir.pwd)
  zh_log = File.join Dir.pwd, "#{opts[:base]}.log.zh.txt"
elsif File.writable?(this_dir)
  zh_log = File.join this_dir, "#{opts[:base]}.log.zh.txt"
else
  require "tempfile"
  zh_log_f = Tempfile.new "zh_log"
  zh_log = zh_log_f.path
end
zh_log_final = File.join log_dir, File.basename(zh_log)
mothur_log   = File.join log_dir, "#{opts[:base]}.log.mothur.txt"

logger = Log4r::Logger.new "ZH Log"

stderr_outputter  = Log4r::StderrOutputter.new("stderr")
file_outputter    = Log4r::FileOutputter.new("file", filename: zh_log)
pattern_formatter =
  Log4r::PatternFormatter.new(pattern: "%-5l -- [%d] -- %M ",
                              date_pattern: "%F %T.%L")

stderr_outputter.formatter = pattern_formatter
file_outputter.formatter = pattern_formatter

logger.outputters << stderr_outputter
logger.outputters << file_outputter

AbortIf::Abi.set_logger logger

logger.debug do
  "Version: #{ZetaHunter::VERSION}, " +
    "Copyright: #{COPYRIGHT}, " +
    "Contact: #{CONTACT}, " +
    "Website: #{WEBSITE}, " +
    "License: #{LICENSE}"
end

logger.info { "Temporary log file location: #{zh_log}. If " +
              "ZetaHunter fails to complete, the log will be here." }

###############
# set up logger
######################################################################

opts[:inaln].each do |fname|
  AbortIf::Abi.abort_unless_file_exists fname
end

AbortIf::Abi.abort_unless_file_exists opts[:db_otu_info]
AbortIf::Abi.abort_unless_file_exists opts[:mask]
AbortIf::Abi.abort_unless_file_exists opts[:db_seqs]
AbortIf::Abi.abort_unless_file_exists opts[:mothur]
AbortIf::Abi.abort_unless_file_exists opts[:sortmerna]
AbortIf::Abi.abort_unless_file_exists opts[:indexdb_rna]

msg = "--threads must be > 0, was #{opts[:threads]}"
AbortIf::Abi.abort_unless opts[:threads] > 0, msg

check = %w[furthest average nearest].one? do |opt|
  opts[:cluster_method] == opt
end

msg = "--cluster-method must be one of furthest, average or nearest"
AbortIf::Abi.abort_unless check, msg


######################################################################
# clean file names for mothur
#############################

opts[:inaln] = opts[:inaln].map { |fname| File.clean_and_copy fname }

opts[:db_otu_info] = File.clean_and_copy opts[:db_otu_info]
opts[:mask]        = File.clean_and_copy opts[:mask]
opts[:db_seqs]     = File.clean_and_copy opts[:db_seqs]

opts[:outdir] = File.clean_fname opts[:outdir]

#############################
# clean file names for mothur
######################################################################

Time.time_it("Create needed directories", logger) do

  AbortIf::Abi.abort_if File.exists?(opts[:outdir]) && !opts[:force],
               "Outdir '#{opts[:outdir]}' already exists. Force " +
               "overwrite with --force or choose a different outdir."

  if File.exists?(opts[:outdir]) && opts[:force]
    logger.info { "We will overwrite #{opts[:outdir]}" }
    FileUtils.rm_r opts[:outdir]
  end

  FileUtils.mkdir_p opts[:outdir]
  FileUtils.mkdir_p outdir_tmp
  FileUtils.mkdir_p dangerous_dir
  FileUtils.mkdir_p otu_calls_dir
  FileUtils.mkdir_p log_dir
  FileUtils.mkdir_p misc_dir
  FileUtils.mkdir_p biom_dir
  FileUtils.mkdir_p chimera_dir
end

# This is way up here because it should note the ORIGINAL file names
# with the sample
library_to_fname_f =
  File.join misc_dir,
            "#{opts[:base]}.sample_id_to_fname.txt"

Time.time_it("Write sample to file name map", logger) do
  File.open(library_to_fname_f, "w") do |f|
    f.puts %w[#Sample FileName].join "\t"

    opts[:inaln].each_with_index do |fname, idx|
      f.puts ["S#{idx+1}", fname].join "\t"
    end
  end

  logger.debug { "Sample to fname map: #{library_to_fname_f}" }
end

inaln_info = opts[:inaln].map { |fname| File.parse_fname fname }

gunzip = `which gunzip`.chomp
AbortIf::Abi.abort_unless $?.exitstatus.zero?, "Cannot find gunzip command"

# ungzip in align files if needed
opts[:inaln] = opts[:inaln].map.with_index do |fname, idx|
  if fname.match(/.gz$/)
    inaln_not_gz = File.join outdir_tmp, "#{inaln_info[idx][:base]}.not_gz.fa"
    cmd = "#{gunzip} -c #{fname} > #{inaln_not_gz}"
    log_cmd logger, cmd
    Process.run_it! cmd
    inaln_info[idx] = inaln_not_gz
  else
    fname
  end
end


redirect_log = ">> #{mothur_log} 2>&1"

chimera_details =
  File.join opts[:outdir], "*.{pintail,uchime,slayer}.*"

inaln_nogaps = File.join outdir_tmp,
                         "#{opts[:base]}.nogaps.fa"

slayer_chimera_info = File.join opts[:outdir],
                                "#{opts[:base]}" +
                                ".slayer.chimeras"
slayer_ids = File.join opts[:outdir],
                       "#{opts[:base]}" +
                       ".slayer.accnos"

uchime_chimera_info = File.join opts[:outdir],
                                "#{opts[:base]}" +
                                ".ref.uchime.chimeras"

pintail_chimera_info = File.join opts[:outdir],
                                "#{opts[:base]}" +
                                ".pintail.chimeras"
pintail_ids = File.join opts[:outdir],
                       "#{opts[:base]}" +
                       ".pintail.accnos"

cluster_me = File.join outdir_tmp, "cluster_me.fa"
cluster_me_dist = File.join outdir_tmp, "cluster_me.phylip.dist"

method = get_cluster_method opts[:cluster_method]

cluster_me_list =
  File.join outdir_tmp, "cluster_me.phylip.#{method}.list"
otu_file_base =
  File.join outdir_tmp, "cluster_me.phylip.#{method}.0"

otu_file = ""

denovo_otus =
  File.join otu_calls_dir, "#{opts[:base]}.otu_calls.denovo.txt"

final_otu_calls_f =
  File.join otu_calls_dir, "#{opts[:base]}.otu_calls.final.txt"

distance_based_otus =
  File.join otu_calls_dir, "#{opts[:base]}.otu_calls.closed_ref.txt"

biom_file =
  File.join biom_dir, "#{opts[:base]}.biom.txt"

chimeric_seqs =
  File.join dangerous_dir, "#{opts[:base]}.dangerous_seqs.chimeras.txt"

probably_not_zetas_f =
  File.join dangerous_dir,
            "#{opts[:base]}.dangerous_seqs.probably_not_zetas.txt"

input_unaln = File.join outdir_tmp, "#{opts[:base]}.unaln.fa"

sortme_blast =
  File.join opts[:outdir], "#{opts[:base]}.unlan.sortme_blast"

closest_seqs =
  File.join misc_dir, "#{opts[:base]}.closest_db_seqs.txt"

# for SortMeRNA
DB_SEQS_UNALN = File.join outdir_tmp, "db_seqs.unaln.fa"
SORTMERNA_IDX = File.join outdir_tmp, "db_seqs.unaln.idx"


######################################################################
# FOR TEST ONLY -- remove outdir before running
###############################################

# cmd = "rm -r #{opts[:outdir]}"
# log_cmd logger, cmd
# Process.run_it cmd

# run = nil
# run = true

###############################################
# FOR TEST ONLY -- remove outdir before running
######################################################################

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

Time.time_it("Process input data", logger) do
  opts[:inaln].each_with_index do |fname, idx|
    process_input_aln file: fname,
                      seq_ids: input_ids,
                      seqs: input_seqs,
                      gap_posns: gap_posns,
                      lib: "S#{idx+1}"
  end

  AbortIf::Abi.abort_if input_seqs.empty?,
                        "Did not find any input seqs"
end

##############################
# process user input alignment
######################################################################

######################################################################
# read provided info
####################

Time.time_it("Read entropy info", logger) do
  entropy = File.read_entropy ENTROPY
  total_entropy = entropy.reduce(:+)
end

Time.time_it("Read db OTU metadata", logger) do
  db_otu_info = read_otu_metadata opts[:db_otu_info]
  # logger.debug { "DB OTU INFO: #{db_otu_info.inspect}" }
end

Time.time_it("Read mask info", logger) do
  mask = read_mask opts[:mask]
  logger.debug { "Num mask bases: #{mask.count}" }
end

Time.time_it("Update shared gap posns with db seqs", logger) do
  process_input_aln file: opts[:db_seqs],
                    seq_ids: db_seq_ids,
                    seqs: db_seqs,
                    gap_posns: gap_posns

  AbortIf::Abi.abort_if db_seqs.empty?, "Did not find any DB seqs"
end

Time.time_it("Read outgroups", logger) do
  outgroup_names = File.to_set OUTGROUPS
end

####################
# read provided info
######################################################################

######################################################################
# degap & mask
##############

shared_gap_posns = gap_posns.reduce(:&)

Time.time_it("Degap and mask", logger) do
  update_with_degapped_and_mask input_seqs, mask, shared_gap_posns
  update_with_degapped_and_mask db_seqs, mask, shared_gap_posns

  AbortIf::Abi.assert_keys input_seqs.first.last, :masked, :degapped
end

##############
# degap & mask
######################################################################

######################################################################
# entropy for masked seqs
#########################

Time.time_it("Get entropy for masked user seqs", logger) do
  input_seqs.each do |head, seqs|
    msg = "Seq '#{head}' is repeated in masked_input_seq_entropy"
    AbortIf::Abi.abort_if masked_input_seq_entropy.has_key?(head), msg

    seq_entropy = get_seq_entropy seqs[:masked], entropy
    masked_input_seq_entropy[head] = seq_entropy
  end
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

  SILVA_GOLD_ALN = File.join outdir_tmp, "silva.gold.align"
  cmd = "#{gunzip} -c #{SILVA_GOLD_ALN_GZ} > #{SILVA_GOLD_ALN}"
  log_cmd logger, cmd
  Process.run_it! cmd

  ##########################
  # unzip the silva gold aln
  ####################################################################

  # mothur params
  mothur_params = opts[:inaln].map do |fname|
    "fasta=#{fname}, " +
      "reference=#{SILVA_GOLD_ALN}, " +
      "outputdir=#{opts[:outdir]}, " +
      "processors=#{opts[:threads]}"
  end

  # Time.time_it("Chimera Slayer", logger) do
  #   # in must be same length as reference
  #   cmd = "#{opts[:mothur]} " +
  #         "'#chimera.slayer(#{mothur_params})' " + # TODO update for multi files
  #         "#{redirect_log}"
  #   log_cmd logger, cmd
  #   Process.run_it! cmd
  # end

  # Time.time_it("Read slayer chimeras", logger) do
  #   File.open(slayer_ids, "rt").each_line do |line|
  #     id = line.chomp
  #     chimeric_ids.store_in_array id, "ChimeraSlayer"

  #     logger.debug { "Chimera Slayer flagged #{id}" }
  #   end
  # end

  Time.time_it("Uchime", logger) do
    mothur_params.each do |params|
      cmd = "#{opts[:mothur]} " +
            "'#chimera.uchime(#{params})' " +
            "#{redirect_log}"
      log_cmd logger, cmd
      Process.run_it! cmd

      check_for_error mothur_log
    end
  end

  # There will be one uchime_ids file per opts[:inaln] fname
  Time.time_it("Read uchime chimeras", logger) do
    opts[:inaln].each do |fname|

      base = File.basename(fname, File.extname(fname))
      uchime_ids = File.join opts[:outdir], "#{base}.ref.uchime.accnos"

      File.open(uchime_ids, "rt").each_line do |line|
        id = line.chomp
        chimeric_ids.store_in_array id, "uchime"

        logger.debug { "Uchime flagged #{id}" }
      end
    end
  end


  # Time.time_it("Pintail", logger) do
  #   cmd = "#{opts[:mothur]} " +
  #         "'#chimera.pintail(fasta=#{opts[:inaln]}, " + # TODO HEHE
  #         "template=#{SILVA_GOLD_ALN}, " +
  #         "conservation=#{SILVA_FREQ}, " +
  #         "quantile=#{SILVA_QUAN}, " +
  #         "outputdir=#{opts[:outdir]}, " +
  #         "processors=#{opts[:threads]})' " +
  #         "#{redirect_log}"
  #   log_cmd logger, cmd
  #   Process.run_it! cmd
  # end

  # Time.time_it("Read Pintail chimeras", logger) do
  #   File.open(pintail_ids, "rt").each_line do |line|
  #     id = line.chomp
  #     chimeric_ids.store_in_array id, "Pintail"

  #     logger.debug { "Pintail flagged #{id}" }
  #   end
  # end

  Time.time_it("Write chimeric seqs", logger) do
    File.open(chimeric_seqs, "w") do |f|
      f.puts %w[#SeqID Sample ChimeraChecker].join "\t"

      chimeric_ids.sort_by { |k, v| k }.each do |id, software|
        clean_id = clean(id)
        AbortIf::Abi.assert_keys input_seqs, clean_id
        sample = input_seqs[clean_id][:lib]
        f.puts [clean_id, sample, software.sort.join(",")].join "\t"
      end
    end

    logger.info { "Chimeric seqs written to #{chimeric_seqs}" }
  end
end

###################
# slay the chimeras
######################################################################

######################################################################
# SortMeRNA distance based closed reference OTU calls
#####################################################


Time.time_it("Unalign DB seqs if needed", logger) do


  File.open(DB_SEQS_UNALN, "w") do |f|
    FastaFile.open(DB_SEQS, "rt").each_record do |head, seq|
      f.puts ">#{clean(head.split(" ").first)}"
      f.puts remove_all_gaps(seq)
    end
  end

  logger.debug { "Aligned DB seqs: #{DB_SEQS}" }
  logger.debug { "Unaligned DB seqs: #{DB_SEQS_UNALN}" }
end

Time.time_it("Unalign input seqs", logger) do
  File.open(input_unaln, "w") do |f|
    input_seqs.each do |head, seq|
      f.puts ">#{head}"
      f.puts remove_all_gaps(seq[:orig])
    end
  end
end

# TODO only do this if it doesn't already exist
Time.time_it("Build SortMeRNA index", logger) do
  AbortIf::Abi.abort_unless_file_exists DB_SEQS_UNALN

  cmd = "#{opts[:indexdb_rna]} " +
        "--ref #{DB_SEQS_UNALN},#{SORTMERNA_IDX}"

  log_cmd logger, cmd
  Process.run_it! cmd
end

Time.time_it("SortMeRNA", logger) do
  cmd = "#{opts[:sortmerna]} " +
        "--ref #{DB_SEQS_UNALN},#{SORTMERNA_IDX} " +
        "--reads #{input_unaln} " +
        "--aligned #{sortme_blast} " +
        "--blast '1 qcov' " +
        "--num_alignments 0"

  # sort me rna adds .blast to the output base
  sortme_blast += ".blast"

  log_cmd logger, cmd
  Process.run_it! cmd
  logger.debug { "SortMeRNA blast: #{sortme_blast}" }
end

# TODO double check that this doesn't assume one hit per query
Time.time_it("Read SortMeRNA blast", logger) do
  File.open(sortme_blast, "rt").each_line do |line|
    user_seq, db_seq_hit, pid, *rest = line.chomp.split "\t"

    pid = pid.to_f
    qcov = rest.last.to_f

    if qcov >= MIN_QCOV
      insert_new_entry =
        (closed_ref_otus.has_key?(user_seq) &&
         closed_ref_otus[user_seq][:pid] < pid) ||
        !closed_ref_otus.has_key?(user_seq)

      if insert_new_entry
        closed_ref_otus[user_seq] = { hit: db_seq_hit,
                                      pid: pid,
                                      qcov: qcov }
      end
    end
  end
end

Time.time_it("Write closest ref seqs and OTU calls", logger) do
  File.open(closest_seqs, "w") do |close_f|
    File.open(distance_based_otus, "w") do |otu_f|
      close_f.puts ["#SeqID",
                    "Sample",
                    "OTU",
                    "PercEntropy",
                    "PercMaskedBases",
                    "Hit",
                    "PID",
                    "QCov"].join "\t"

      otu_f.puts ["#SeqID",
                  "Sample",
                  "OTU",
                  "PercEntropy",
                  "PercMaskedBases",
                  "Hit",
                  "PID",
                  "QCov"].join "\t"

      closed_ref_otus.each do |user_seq, info|
        AbortIf::Abi.assert_keys masked_input_seq_entropy, user_seq
        AbortIf::Abi.assert_keys input_seqs, user_seq

        perc_total_entropy =
          masked_input_seq_entropy[user_seq][:perc_total_entropy]
        perc_bases_in_mask =
          masked_input_seq_entropy[user_seq][:perc_bases_in_mask]

        # TODO assert db_otu_info.keys contains info[:hit]
        close_f.puts [user_seq,
                      input_seqs[user_seq][:lib],
                      db_otu_info[info[:hit]][:otu],
                      perc_total_entropy,
                      perc_bases_in_mask,
                      info[:hit],
                      info[:pid],
                      info[:qcov]].join "\t"

        if info[:pid] < 97.0 # will be clustered later
          AbortIf::Abi.assert input_seqs.has_key? user_seq
          cluster_these_user_seqs[user_seq] = input_seqs[user_seq]
          closest_to_outgroups << user_seq
        else

          otu_f.puts [user_seq,
                      input_seqs[user_seq][:lib],
                      db_otu_info[info[:hit]][:otu],
                      perc_total_entropy,
                      perc_bases_in_mask,
                      info[:hit],
                      info[:pid],
                      info[:qcov]].join "\t"
        end
      end
    end
  end

  logger.debug { "Closest DB seqs: #{closest_seqs}" }
  logger.debug { "Distance based OTU calls written " +
                 "to #{distance_based_otus}" }
end

#####################################################
# SortMeRNA distance based closed reference OTU calls
######################################################################


######################################################################
# cluster
#########

run = true
Time.time_it("Write masked, combined fasta", logger) do
  AbortIf::Abi.refute input_seqs.empty?, "Did not find any input seqs"
  AbortIf::Abi.refute db_seqs.empty?, "Did not find any DB seqs"
  File.open(cluster_me, "w") do |f|
    cluster_these_user_seqs.each do |head, seqs|
      f.printf ">%s\n%s\n", head, seqs[:masked]
    end

    db_seqs.each do |head, seqs|
      f.printf ">%s\n%s\n", head, seqs[:masked]
    end
  end

  logger.info { "We will cluster this file: #{cluster_me}" }
end

Time.time_it("Distance", logger) do
  cmd = "#{opts[:mothur]} " +
        "'#dist.seqs(fasta=#{cluster_me}, " +
        "outputdir=#{outdir_tmp}, " +
        "output=lt, " +
        "processors=#{opts[:threads]})' " +
        "#{redirect_log}"

  log_cmd logger, cmd
  Process.run_it! cmd

  check_for_error mothur_log
end

# warn "EMERGENCY BRAKE ENGAGED!"
# exit

Time.time_it("Cluster", logger) do
  cmd = "#{opts[:mothur]} " +
        "'#cluster(phylip=#{cluster_me_dist}, " +
        "method=#{opts[:cluster_method]})' " +
        "#{redirect_log}"

  log_cmd logger, cmd
  Process.run_it! cmd

  check_for_error mothur_log
end

Time.time_it("Get OTU list", logger) do
  cmd = "#{opts[:mothur]} '#get.otulist(list=#{cluster_me_list})' " +
        "#{redirect_log}"
  log_cmd logger, cmd
  Process.run_it! cmd

  check_for_error mothur_log
end

#########
# cluster
######################################################################

######################################################################
# assigned detailed OTU info
############################

Time.time_it("Find OTU file", logger) do
  %w[03 02 01].each do |pid|
    otu_file = "#{otu_file_base}.#{pid}.otu"
    break if File.exists? otu_file
    logger.debug { "OTU file #{otu_file} not found" }
  end

  AbortIf::Abi.abort_unless_file_exists otu_file
  logger.debug { "For OTUs, using #{otu_file}" }
end

Time.time_it("Assign de novo OTUs", logger) do
  # TODO generate good names for new OTUs
  File.open(probably_not_zetas_f, "w") do |nzf|
    nzf.puts %w[#SeqID Sample DBHit PID].join "\t"

    File.open(denovo_otus, "w") do |f|
      f.puts %w[#SeqID Sample OTU PercEntropy PercMaskedBases OTUComp].join "\t"

      File.open(otu_file, "rt").each_line do |line|
        otu, id_str = line.chomp.split "\t"
        ids = id_str.split ","
        otu_size = ids.count

        AbortIf::Abi.abort_if otu_size.zero?,
                              "OTU '#{otu}' had size zero"

        otu_calls = get_otu_calls ids, db_otu_info, input_ids

        otu_call_counts = get_otu_call_counts otu_calls
        otu_call = get_otu_call otu_call_counts

        only_input_ids = ids.select { |id| input_ids.include?(id) }

        only_input_ids.each do |id|
          AbortIf::Abi.assert_keys input_seqs, id
          sample = input_seqs[id][:lib]

          if otu_size == 1 && closest_to_outgroups.include?(id)
            nzf.puts [id,
                      sample,
                      closed_ref_otus[id][:hit],
                      closed_ref_otus[id][:pid]].join "\t"

            logger.info { "Seq: #{id} is probably not a Zeta" }
          else
            AbortIf::Abi.assert_keys masked_input_seq_entropy, id
            perc_entropy = masked_input_seq_entropy[id]
            f.puts [id,
                    sample,
                    otu_call,
                    perc_entropy[:perc_total_entropy],
                    perc_entropy[:perc_bases_in_mask],
                    otu_call_counts.inspect].join "\t"
          end
        end
      end
    end
  end

  logger.info { "seqs that probably are not Zetas: #{probably_not_zetas_f}" }
  logger.info { "de novo OTU calls written to #{denovo_otus}" }
end

Time.time_it("Write final OTU calls", logger) do
  File.open(final_otu_calls_f, "w") do |f|
    f.puts ["#SeqID",
            "Sample",
            "OTU",
            "PercEntropy",
            "PercMaskedBases"].join "\t"

    File.open(distance_based_otus, "rt").each_line do |line|
      unless line.start_with? "#"
        seq, sample, otu, ent, masked, *rest = line.chomp.split "\t"

        f.puts [seq, sample, otu, ent, masked].join "\t"
      end
    end

    File.open(denovo_otus, "rt").each_line do |line|
      unless line.start_with? "#"
        seq, sample, otu, ent, masked, *rest = line.chomp.split "\t"

        f.puts [seq, sample, otu, ent, masked].join "\t"
      end
    end
  end

  logger.info { "Final OTU calls written to #{final_otu_calls_f}" }
end

############################
# assigned detailed OTU info
######################################################################

######################################################################
# write biom file
#################

Time.time_it("Write biom file", logger) do
  File.open(biom_file, "w") do |f|
    sample_arr = opts[:inaln].map.with_index do |_, idx|
      "S#{idx+1}"
    end

    otu_counts = {}
    f.puts ["#OTU ID", sample_arr].flatten.join "\t"
    File.open(final_otu_calls_f).each_line do |line|
      unless line.start_with? "#"
        seqid, sample, otu, _, _ = line.chomp.split "\t"

        if otu_counts.has_key? otu
          if otu_counts[otu].has_key? sample
            otu_counts[otu][sample] += 1
          else
            otu_counts[otu][sample] = 1
          end
        else
          otu_counts[otu] = { sample => 1 }
        end
      end
    end

    otu_counts.each do |otu, info|
      sample_counts = sample_arr.map do |key|
        if info.has_key? key
          count = info[key]
        else
          count = 0
        end

      end

      f.puts [otu, sample_counts].join "\t"
    end
  end
end

#################
# write biom file
######################################################################


######################################################################
# clean up
##########

Time.time_it("Clean up", logger) do

  FileUtils.rm Dir.glob File.join Dir.pwd, "*.tmp.uchime_formatted"

  FileUtils.rm Dir.glob File.join opts[:outdir], "mothur.*.logfile"
  FileUtils.rm Dir.glob File.join Dir.pwd, "mothur.*.logfile"

  FileUtils.rm_r outdir_tmp

  FileUtils.mv Dir.glob(chimera_details), chimera_dir

  FileUtils.mv(sortme_blast,
               File.join(misc_dir,
                         "#{opts[:base]}.all_sortmerna_db_hits.txt"))

  FileUtils.mv zh_log, zh_log_final
end

##########
# clean up
######################################################################

logger.info { "FINAL FILE OUTPUTS"                           }
logger.info { "Biom file:           #{biom_file}"            }
logger.info { "Final OTUs:          #{final_otu_calls_f}"    }
logger.info { "Denovo OTUs:         #{denovo_otus}"          }
logger.info { "Closed ref OTUs:     #{distance_based_otus}"  }
logger.info { "SortMeRNA output:    #{sortme_blast}"         }
logger.info { "Closest DB seqs:     #{closest_seqs}"         }
logger.info { "Chimeras:            #{chimeric_seqs}"        }
logger.info { "Probably not zetas:  #{probably_not_zetas_f}" }
logger.info { "Sample to fname map: #{library_to_fname_f}"   }
logger.info { "ZetaHunter log:      #{zh_log_final}"         }
logger.info { "Mothur log:          #{mothur_log}"           }
