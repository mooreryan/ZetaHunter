require_relative File.join "lib", "lib_helper.rb"

include Const
include Utils
include Assert
include AbortIf

Process.extend CoreExtensions::Process
Time.extend CoreExtensions::Time
File.extend CoreExtensions::File
Hash.include CoreExtensions::Hash

logger = Logger.new STDERR

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
      "Input alignment",
      type: :string,
      default: TEST_ALN)

  opt(:outdir,
      "Directory for output",
      type: :string,
      default: TEST_OUTDIR)

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
end

assert_file opts[:inaln]
assert_file opts[:db_otu_info]
assert_file opts[:mask]
assert_file opts[:db_seqs]
assert_file opts[:mothur]
assert_file opts[:sortmerna]
assert_file opts[:indexdb_rna]


assert opts[:threads] > 0,
       "--threads must be > 0, was %d",
       opts[:threads]

check = %w[furthest average nearest].one? do |opt|
  opts[:cluster_method] == opt
end
assert check,
       "--cluster-method must be one of furthest, average or " +
       "nearest"

######################################################################
# clean file names for mothur
#############################

opts[:inaln]       = File.clean_and_copy opts[:inaln]
opts[:db_otu_info] = File.clean_and_copy opts[:db_otu_info]
opts[:mask]        = File.clean_and_copy opts[:mask]
opts[:db_seqs]     = File.clean_and_copy opts[:db_seqs]

opts[:outdir] = File.clean_fname opts[:outdir]

#############################
# clean file names for mothur
######################################################################

outdir_tmp = File.join opts[:outdir], "tmp"

Time.time_it("Create needed directories", logger) do
  FileUtils.mkdir_p opts[:outdir]
  FileUtils.mkdir_p outdir_tmp
end

inaln_info = File.parse_fname opts[:inaln]

gunzip = `which gunzip`.chomp
abort_unless $?.exitstatus.zero?, "Cannot find gunzip command"

inaln_not_gz = File.join outdir_tmp, "#{inaln_info[:base]}.not_gz.fa"
if opts[:inaln].match(/.gz$/)
  cmd = "#{gunzip} -c #{opts[:inaln]} > #{inaln_not_gz}"
  log_cmd logger, cmd
  Process.run_it! cmd
  opts[:inaln] = inaln_not_gz
  inaln_info = File.parse_fname opts[:inaln]
end

chimera_dir = File.join opts[:outdir], "chimera_details"

chimera_details =
  File.join opts[:outdir], "*.{pintail,uchime,slayer}.*"

inaln_nogaps = File.join outdir_tmp,
                         "#{inaln_info[:base]}.nogaps.fa"

slayer_chimera_info = File.join opts[:outdir],
                                "#{inaln_info[:base]}" +
                                ".slayer.chimeras"
slayer_ids = File.join opts[:outdir],
                       "#{inaln_info[:base]}" +
                       ".slayer.accnos"

uchime_chimera_info = File.join opts[:outdir],
                                "#{inaln_info[:base]}" +
                                ".ref.uchime.chimeras"
uchime_ids = File.join opts[:outdir],
                       "#{inaln_info[:base]}" +
                       ".ref.uchime.accnos"

pintail_chimera_info = File.join opts[:outdir],
                                "#{inaln_info[:base]}" +
                                ".pintail.chimeras"
pintail_ids = File.join opts[:outdir],
                       "#{inaln_info[:base]}" +
                       ".pintail.accnos"

cluster_me = File.join outdir_tmp, "cluster_me.fa"
cluster_me_dist = File.join outdir_tmp, "cluster_me.phylip.dist"

method = get_cluster_method opts[:cluster_method]

cluster_me_list =
  File.join outdir_tmp, "cluster_me.phylip.#{method}.list"
otu_file_base =
  File.join outdir_tmp, "cluster_me.phylip.#{method}.0"

otu_file = ""

otu_calls_f =
  File.join opts[:outdir], "#{inaln_info[:base]}.denovo.otu_calls.txt"

final_otu_calls_f =
  File.join opts[:outdir], "#{inaln_info[:base]}.final.otu_calls.txt"

chimeric_seqs =
  File.join opts[:outdir], "#{inaln_info[:base]}.dangerous_seqs.txt"

input_unaln = File.join opts[:outdir], "input_unaln.fa"
sortme_blast = File.join opts[:outdir], "input_unaln.sortme_blast"
closest_seqs =
  File.join opts[:outdir],
            "#{inaln_info[:base]}.closest_db_seqs.txt"

distance_based_otus =
  File.join opts[:outdir],
            "#{inaln_info[:base]}.distance_based_otus.txt"

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
  process_input_aln file: opts[:inaln],
                    seq_ids: input_ids,
                    seqs: input_seqs,
                    gap_posns: gap_posns

  refute input_seqs.empty?, "Did not find any input seqs"
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

  refute db_seqs.empty?, "Did not find any DB seqs"
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

  assert_keys input_seqs.first.last, :masked, :degapped
end

##############
# degap & mask
######################################################################

######################################################################
# entropy for masked seqs
#########################

Time.time_it("Get entropy for masked user seqs", logger) do
  input_seqs.each do |head, seqs|
    refute_has_key masked_input_seq_entropy, head
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
  mothur_params = "fasta=#{opts[:inaln]}, " +
                  "reference=#{SILVA_GOLD_ALN}, " +
                  "outputdir=#{opts[:outdir]}, " +
                  "processors=#{opts[:threads]}"

  # Time.time_it("Chimera Slayer", logger) do
  #   # in must be same length as reference
  #   cmd = "#{opts[:mothur]} " +
  #         "'#chimera.slayer(#{mothur_params})'"
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
    cmd = "#{opts[:mothur]} " +
          "'#chimera.uchime(#{mothur_params})'"
    log_cmd logger, cmd
    Process.run_it! cmd
  end

  Time.time_it("Read uchime chimeras", logger) do
    File.open(uchime_ids, "rt").each_line do |line|
      id = line.chomp
      chimeric_ids.store_in_array id, "uchime"

      logger.debug { "Uchime flagged #{id}" }
    end
  end


  # Time.time_it("Pintail", logger) do
  #   cmd = "#{opts[:mothur]} " +
  #         "'#chimera.pintail(fasta=#{opts[:inaln]}, " +
  #         "template=#{SILVA_GOLD_ALN}, " +
  #         "conservation=#{SILVA_FREQ}, " +
  #         "quantile=#{SILVA_QUAN}, " +
  #         "outputdir=#{opts[:outdir]}, " +
  #         "processors=#{opts[:threads]})'"
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
      chimeric_ids.sort_by { |k, v| k }.each do |id, software|
        f.puts [id, software.sort.join(",")].join "\t"
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
  refute DB_SEQS_UNALN.empty?, "Did not find unaligned DB seqs"

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
        "--blast '1 qcov'"

  # sort me rna adds .blast to the output base
  sortme_blast += ".blast"

  log_cmd logger, cmd
  Process.run_it! cmd
  logger.debug { "SortMeRNA blast: #{sortme_blast}" }
end

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
                   "OTU",
                   "PercEntropy",
                   "PercMaskedBases",
                   "Hit",
                   "PID",
                   "QCov"].join "\t"

      otu_f.puts ["#SeqID",
                   "OTU",
                   "PercEntropy",
                   "PercMaskedBases",
                   "Hit",
                   "PID",
                   "QCov"].join "\t"

      closed_ref_otus.each do |user_seq, info|
        assert_keys masked_input_seq_entropy, user_seq

        perc_total_entropy =
          masked_input_seq_entropy[user_seq][:perc_total_entropy]
        perc_bases_in_mask =
          masked_input_seq_entropy[user_seq][:perc_bases_in_mask]

        # TODO assert db_otu_info.keys contains info[:hit]
        close_f.puts [user_seq,
                      db_otu_info[info[:hit]][:otu],
                      perc_total_entropy,
                      perc_bases_in_mask,
                      info[:hit],
                      info[:pid],
                      info[:qcov]].join "\t"

        if info[:pid] < 97.0 # will be clustered later
          assert input_seqs.has_key? user_seq
          cluster_these_user_seqs[user_seq] = input_seqs[user_seq]
          closest_to_outgroups << user_seq
        else

          otu_f.puts [user_seq,
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
  refute input_seqs.empty?, "Did not find any input seqs"
  refute db_seqs.empty?, "Did not find any DB seqs"
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
        "processors=#{opts[:threads]})'"

  log_cmd logger, cmd
  Process.run_it! cmd
end

# warn "EMERGENCY BRAKE ENGAGED!"
# exit

Time.time_it("Cluster", logger) do
  cmd = "#{opts[:mothur]} " +
        "'#cluster(phylip=#{cluster_me_dist}, " +
        "method=#{opts[:cluster_method]})'"

  log_cmd logger, cmd
  Process.run_it! cmd
end

Time.time_it("Get OTU list", logger) do
  cmd = "#{opts[:mothur]} '#get.otulist(list=#{cluster_me_list})'"
  log_cmd logger, cmd
  Process.run_it! cmd
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

  assert_file otu_file
  logger.debug { "For OTUs, using #{otu_file}" }
end

probably_not_zetas_f =
  File.join opts[:outdir],
            "#{inaln_info[:base]}.probably_not_zetas.txt"

possibly_not_zetas_f =
  File.join opts[:outdir],
            "#{inaln_info[:base]}.possibly_not_zetas.txt"

Time.time_it("Assign de novo OTUs", logger) do
  # TODO generate good names for new OTUs
  File.open(possibly_not_zetas_f, "w") do |pnzf|
    pnzf.puts %w[#SeqID DBHit PID].join "\t"
    File.open(probably_not_zetas_f, "w") do |nzf|
      nzf.puts %w[#SeqID DBHit PID].join "\t"

      File.open(otu_calls_f, "w") do |f|
        f.puts %w[#SeqID OTU PercEntropy PercMaskedBases OTUComp].join "\t"

        File.open(otu_file, "rt").each_line do |line|
          otu, id_str = line.chomp.split "\t"
          ids = id_str.split ","
          otu_size = ids.count

          refute otu_size.zero?
          logger.debug { "MOTHUR OTU #{otu} had #{otu_size} sequence(s)" }

          otu_calls = get_otu_calls ids, db_otu_info, input_ids

          otu_call_counts = get_otu_call_counts otu_calls
          otu_call = get_otu_call otu_call_counts

          only_input_ids = ids.select { |id| input_ids.include?(id) }

          only_input_ids.each do |id|
            if otu_size == 1 && closest_to_outgroups.include?(id)
              nzf.puts [id,
                        closed_ref_otus[id][:hit],
                        closed_ref_otus[id][:pid]].join "\t"

              logger.info { "Seq: #{id} is probably not a Zeta" }
            else
              assert_keys masked_input_seq_entropy, id
              perc_entropy = masked_input_seq_entropy[id]
              f.puts [id,
                      otu_call,
                      perc_entropy[:perc_total_entropy],
                      perc_entropy[:perc_bases_in_mask],
                      otu_call_counts.inspect].join "\t"
            end
          end
        end
      end
    end
  end

  logger.info { "seqs that probably are not Zetas: #{probably_not_zetas_f}" }
  logger.info { "de novo OTU calls written to #{otu_calls_f}" }
end

Time.time_it("Write final OTU calls", logger) do
  File.open(final_otu_calls_f, "w") do |f|
    f.puts ["#SeqID",
            "OTU",
            "PercEntropy",
            "PercMaskedBases"].join "\t"

    File.open(distance_based_otus, "rt").each_line do |line|
      unless line.start_with? "#"
        seq, otu, ent, masked, *rest = line.chomp.split "\t"

        f.puts [seq, otu, ent, masked].join "\t"
      end
    end

    File.open(otu_calls_f, "rt").each_line do |line|
      unless line.start_with? "#"
        seq, otu, ent, masked, *rest = line.chomp.split "\t"

        f.puts [seq, otu, ent, masked].join "\t"
      end
    end
  end

  logger.info { "Final OTU calls written to #{final_otu_calls_f}" }
end

############################
# assigned detailed OTU info
######################################################################

######################################################################
# clean up
##########

Time.time_it("Clean up", logger) do
  FileUtils.rm Dir.glob File.join File.dirname(__FILE__), "mothur.*.logfile"
  FileUtils.rm Dir.glob File.join File.dirname(__FILE__), "formatdb.log"
  FileUtils.rm Dir.glob File.join TEST_DIR, "*.tmp.uchime_formatted"
  FileUtils.rm Dir.glob File.join opts[:outdir], "mothur.*.logfile"
  FileUtils.rm_r outdir_tmp
  FileUtils.mkdir_p chimera_dir
  FileUtils.mv Dir.glob(chimera_details), chimera_dir
end

##########
# clean up
######################################################################
