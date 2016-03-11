require_relative File.join "lib", "lib_helper.rb"

include Const
include Assert
include Utils

Process.extend CoreExtensions::Process
Time.extend CoreExtensions::Time
File.extend CoreExtensions::File
Hash.include CoreExtensions::Hash

logger = Logger.new STDERR

this_dir = File.dirname(__FILE__)


require "trollop"

opts = Trollop.options do
  banner <<-EOS

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
      default: MOTHUR)

  opt(:cluster_method, "Either furthest, average, or nearest",
      type: :string,
      default: "average")
end

# opts = {
#   inaln: TEST_ALN,
#   outdir: TEST_OUTDIR,
#   threads: 2,
#   db_otu_info: DB_OTU_INFO,
#   mask: MASK,
#   db_seqs: DB_SEQS,
# }

assert_file opts[:inaln]
assert_file opts[:db_otu_info]
assert_file opts[:mask]
assert_file opts[:db_seqs]
assert_file opts[:mothur]

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

infiles = [opts[:inaln], opts[:db_otu_info], opts[:mask], opts[:db_seqs]]
new_fnames = infiles.map do |fname|
  new_fname = clean_fname fname
  new_dirname = File.dirname new_fname

  unless new_fname == fname
    title = "Creating directory #{new_dirname} if it does not exist"
    Time.time_it(title, logger) do
      FileUtils.mkdir_p new_dirname
    end

    Time.time_it("Copying #{fname} to #{new_fname}", logger) do
      FileUtils.cp fname, new_fname
    end

    assert_file new_fname
  end

  new_fname
end
opts[:inaln], opts[:db_otu_info], opts[:mask], opts[:db_seqs] = new_fnames

opts[:outdir] = clean_fname opts[:outdir]

#############################
# clean file names for mothur
######################################################################

inaln_info = File.parse_fname opts[:inaln]

outdir_tmp = File.join opts[:outdir], "tmp"

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
cluster_me_dist = File.join outdir_tmp, "cluster_me.dist"
cluster_me_dist_seqs_removed =
  File.join outdir_tmp,
            "cluster_me.usr_seqs_matching_db_removed.dist"
cluster_me_dist_seqs_removed_names_file =
  File.join outdir_tmp,
            "cluster_me.usr_seqs_matching_db_removed.names"

if opts[:cluster_method] == "furthest"
  cluster_method = "fn"
elsif opts[:cluster_method] == "average"
  cluster_method = "an"
elsif opts[:cluster_method] == "nearest"
  cluster_method = "nn"
else
  assert false, "problem with --cluster-method"
end

cluster_me_dist_seqs_removed_list =
  File.join outdir_tmp,
            "cluster_me.usr_seqs_matching_db_removed." +
            "#{cluster_method}.list"
otu_file_base =
  File.join outdir_tmp,
            "cluster_me.usr_seqs_matching_db_removed." +
            "#{cluster_method}.0"


# cluster_me_list =
#   File.join outdir_tmp, "cluster_me.phylip.#{cluster_method}.list"
# otu_file_base =
#   File.join outdir_tmp, "cluster_me.phylip.#{cluster_method}.0"


otu_file = ""

closest_seqs =
  File.join opts[:outdir], "#{inaln_info[:base]}.closest_seqs.txt"

user_seqs_matching_outgroups =
  File.join opts[:outdir],
            "#{inaln_info[:base]}.seqs_matching_outgroups.txt"

distance_based_otus =
  File.join opts[:outdir],
            "#{inaln_info[:base]}.distance_based_otus.txt"

otu_calls_f =
  File.join opts[:outdir], "#{inaln_info[:base]}.denovo.otu_calls.txt"

final_otu_calls_f =
  File.join opts[:outdir], "#{inaln_info[:base]}.final.otu_calls.txt"

chimeric_seqs =
  File.join opts[:outdir], "#{inaln_info[:base]}.dangerous_seqs.txt"

######################################################################
# FOR TEST ONLY -- remove outdir before running
###############################################

cmd = "rm -r #{opts[:outdir]}"
log_cmd logger, cmd
Process.run_it cmd

# run = nil
# run = true

###############################################
# FOR TEST ONLY -- remove outdir before running
######################################################################

# containers

chimeric_ids             = {}

# { acc => { :otu, :clone, :num } }
db_otu_info              = {}

db_seq_ids               = Set.new
db_seqs                  = {}
entropy                  = []
gap_posns                = []
input_dists              = {}
input_ids                = Set.new
input_seqs               = {}
mask                     = []
masked_input_seq_entropy = {}
outgroup_names           = Set.new
otu_info                 = []
total_entropy            = 0

# new things for dist
input_dists_less_than_03 = nil
already_called_otus = nil

# mothur params
mothur_params = "fasta=#{opts[:inaln]}, " +
                "reference=#{GOLD_ALN}, " +
                "outputdir=#{opts[:outdir]}, " +
                "processors=#{opts[:threads]}"

Time.time_it("Create needed directories", logger) do
  FileUtils.mkdir_p opts[:outdir]
  FileUtils.mkdir_p outdir_tmp
end

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
  File.open(ENTROPY).each_line do |line|
    idx, ent = line.chomp.split "\t"
    assert !idx.nil? && !idx.empty?
    assert !ent.nil? && !ent.empty?

    entropy[idx.to_i] = ent.to_f
  end

  assert entropy.count == MASK_LEN,
         "Entropy count was %d should be %d",
         entropy.count,
         MASK_LEN

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
  File.open(OUTGROUPS).each_line do |line|
    outgroup_names << line.chomp
  end
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

# Time.time_it("Remove all gaps", logger) do
#   cmd = "ruby #{REMOVE_ALL_GAPS} #{opts[:inaln]} > #{inaln_nogaps}"
#   log_cmd logger, cmd
#   Process.run_it! cmd
# end

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

# Time.time_it("Chimera Slayer", logger) do
#   # in must be same length as reference
#   cmd = "#{opts[:mothur]} " +
#         "'#chimera.slayer(#{mothur_params})'"
#   log_cmd logger, cmd
#   Process.run_it! cmd
# end

# Time.time_it("Read slayer chimeras", logger) do
#   File.open(slayer_ids).each_line do |line|
#     id = line.chomp
#     chimeric_ids.store_in_array id, "ChimeraSlayer"

#     logger.debug { "Chimera Slayer flagged #{id}" }
#   end
# end

# Time.time_it("Uchime", logger) do
#   cmd = "#{opts[:mothur]} " +
#         "'#chimera.uchime(#{mothur_params})'"
#   log_cmd logger, cmd
#   Process.run_it! cmd
# end

# Time.time_it("Read uchime chimeras", logger) do
#   File.open(uchime_ids).each_line do |line|
#     id = line.chomp
#     chimeric_ids.store_in_array id, "uchime"

#     logger.debug { "Uchime flagged #{id}" }
#   end
# end

# Time.time_it("Pintail", logger) do
#   cmd = "#{opts[:mothur]} " +
#         "'#chimera.pintail(fasta=#{opts[:inaln]}, " +
#         "template=#{GOLD_ALN}, " +
#         "conservation=#{SILVA_FREQ}, " +
#         "quantile=#{SILVA_QUAN}, " +
#         "outputdir=#{opts[:outdir]}, " +
#         "processors=#{opts[:threads]})'"
#   log_cmd logger, cmd
#   Process.run_it! cmd
# end

# Time.time_it("Read Pintail chimeras", logger) do
#   File.open(pintail_ids).each_line do |line|
#     id = line.chomp
#     chimeric_ids.store_in_array id, "Pintail"

#     logger.debug { "Pintail flagged #{id}" }
#   end
# end

# Time.time_it("Write chimeric seqs", logger) do
#   File.open(chimeric_seqs, "w") do |f|
#     chimeric_ids.sort_by { |k, v| k }.each do |id, software|
#       f.puts [id, software.sort.join(",")].join "\t"
#     end
#   end

#   logger.info { "Chimeric seqs written to #{chimeric_seqs}" }
# end

###################
# slay the chimeras
######################################################################

run = true
Time.time_it("Write masked, combined fasta", logger) do
  refute input_seqs.empty?, "Did not find any input seqs"
  refute db_seqs.empty?, "Did not find any DB seqs"
  File.open(cluster_me, "w") do |f|
    input_seqs.each do |head, seqs|
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
        "output=column, " +
        "processors=#{opts[:threads]})'"

  log_cmd logger, cmd
  Process.run_it! cmd
end

######################################################################
# parse the distance file
#########################

Time.time_it("Parse distance file", logger) do
  File.open(cluster_me_dist).each_line do |line|
    s1, s2, dist = line.chomp.split " "
    new_dist = dist.to_f

    s1_is_user_seq = input_ids.include? s1
    s2_is_user_seq = input_ids.include? s2

    s1_already_seen = input_dists.has_key? s1
    s2_already_seen = input_dists.has_key? s2

    if s1_is_user_seq && s2_is_user_seq
    # pass -- not checking only user seqs now
    elsif s1_is_user_seq
      if ((s1_already_seen && new_dist < input_dists[s1][:dist]) ||
          !s1_already_seen)
        input_dists[s1] = { seq: s2, dist: new_dist }
      end
    elsif s2_is_user_seq
      if ((s2_already_seen && new_dist < input_dists[s2][:dist]) ||
          !s2_already_seen)
        input_dists[s2] = { seq: s1, dist: new_dist }
      end
    else
      # pass -- not checking only database seqs
    end
  end
end

#########################
# parse the distance file
######################################################################

######################################################################
# check for user seqs that are most similar to outgroups
########################################################

# currently, this is just noting them
Time.time_it("Write seqs matching outgroups", logger) do
  File.open(user_seqs_matching_outgroups, "w") do |f|
    input_dists.each do |seq, closest|
      if is_outgroup? db_otu_info, closest[:seq]
        f.puts [seq, closest[:seq], closest[:dist]].join "\t"
      end
    end
  end
end

########################################################
# check for user seqs that are most similar to outgroups
######################################################################


######################################################################
# write closest seqs
####################

Time.time_it("Write closest seqs", logger) do
  File.open(closest_seqs, "w") do |f|
    input_dists.each do |seq, info|
      closest_seq = info[:seq]
      assert db_otu_info.has_key? closest_seq
      otu = db_otu_info[closest_seq][:otu]

      f.puts [seq, otu, info[:seq], info[:dist]].join "\t"
    end
  end
end

####################
# write closest seqs
######################################################################

######################################################################
# make distance based OTU calls
###############################

# any user seq that has it's closest db < 0.03
# TODO can this happen? usrA => usrB dist 0.01, usrA => dbseq1 dist
# 0.02, usrB => dbseq2 dist 0.01, so usrA goes with dbseq1, usrB goes
# with dbseq2, but the are closest to one another?

Time.time_it("Distance based OTU calls", logger) do
  input_dists_less_than_03 =
    input_dists.select { |seq, info| info[:dist] < 0.03 }

  File.open(distance_based_otus, "w") do |f|
    input_dists_less_than_03.each do |seq, info|
      assert_keys db_otu_info, info[:seq]

      assert_keys masked_input_seq_entropy, seq

      perc_total_entropy =
        masked_input_seq_entropy[seq][:perc_total_entropy]
      perc_bases_in_mask =
        masked_input_seq_entropy[seq][:perc_bases_in_mask]

      f.puts [seq,
              db_otu_info[info[:seq]][:otu],
              perc_total_entropy,
              perc_bases_in_mask,
              info[:seq],
              info[:dist]].join "\t"
    end
  end

  logger.info { "Distance based OTU calls written " +
                "to #{distance_based_otus}" }
end

###############################
# make distance based OTU calls
######################################################################

######################################################################
# remove seqs from dist file already assigned to OTU
####################################################

Time.time_it("Remove already classified seqs", logger) do
  already_called_otus = input_dists_less_than_03.keys
  File.open(cluster_me_dist_seqs_removed, "w") do |f|
    File.open(cluster_me_dist).each_line do |line|
      line_includes_already_called_seq =
        already_called_otus.any? do |seq|
        line.include? seq
      end

      unless line_includes_already_called_seq
        f.puts line
      end
    end
  end
end

####################################################
# remove seqs from dist file already assigned to OTU
######################################################################

######################################################################
# write names file
##################

all_ids = db_seq_ids + input_ids
keep_these = all_ids - already_called_otus

File.open(cluster_me_dist_seqs_removed_names_file, "w") do |f|
  keep_these.each do |id|
    f.puts [id, id].join "\t"
  end
end

##################
# write names file
######################################################################

######################################################################
# cluster
#########

Time.time_it("Cluster", logger) do
  cmd = "#{opts[:mothur]} " +
        "'#cluster(column=#{cluster_me_dist_seqs_removed}, " +
        "name=#{cluster_me_dist_seqs_removed_names_file}, " +
        "method=#{opts[:cluster_method]})'"

  log_cmd logger, cmd
  Process.run_it! cmd
end

Time.time_it("Get OTU list", logger) do
  cmd = "#{opts[:mothur]} " +
        "'#get.otulist(list=#{cluster_me_dist_seqs_removed_list})'"
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
  # TODO is unique okay here?
  %w[03 02 01].each do |pid|
    otu_file = "#{otu_file_base}.#{pid}.otu"
    break if File.exists? otu_file
    logger.debug { "OTU file #{otu_file} not found" }
  end

  assert_file otu_file
  logger.debug { "For OTUs, using #{otu_file}" }
end

Time.time_it("Assign OTUs", logger) do
  # TODO generate good names for new OTUs
  File.open(otu_calls_f, "w") do |f|
    f.puts %w[#SeqID OTU PercEntropy PercMaskedBases OTUComp].join "\t"

    File.open(otu_file).each_line do |line|
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
  logger.info { "OTU calls written to #{otu_calls_f}" }
end

############################
# assigned detailed OTU info
######################################################################

######################################################################
# combine distance and de novo otu calls
########################################

final_otus = {}

Time.time_it("Write final OTU calls", logger) do
  File.open(distance_based_otus).each_line do |line|
    unless line.start_with? "#"
      seq, otu, ent1, ent2, *rest = line.chomp.split "\t"

      refute final_otus.has_key? seq

      final_otus[seq] = { otu: otu, ent1: ent1, ent2: ent2, comp: "NA" }
    end
  end

  File.open(otu_calls_f).each_line do |line|
    unless line.start_with? "#"
      seq, otu, ent1, ent2, comp = line.chomp.split "\t"

      refute final_otus.has_key? seq

      final_otus[seq] = { otu: otu, ent1: ent1, ent2: ent2, comp: comp }
    end
  end

  File.open(final_otu_calls_f, "w") do |f|
    f.puts ["SeqID",
            "OTU",
            "PercEntropy",
            "PercMaskedBases",
            "OTUComp"].join "\t"

    final_otus.each do |seq, info|
      f.puts [seq,
              info[:otu],
              info[:ent1],
              info[:ent2],
              info[:comp]].join "\t"
    end
  end

  logger.info { "Final OTU calls written to #{final_otu_calls_f}" }
end

########################################
# combine distance and de novo otu calls
######################################################################


######################################################################
# clean up
##########

Time.time_it("Clean up", logger) do
  # FileUtils.rm Dir.glob File.join File.dirname(__FILE__), "mothur.*.logfile"
  # FileUtils.rm Dir.glob File.join File.dirname(__FILE__), "formatdb.log"
  # FileUtils.rm Dir.glob File.join TEST_DIR, "*.tmp.uchime_formatted"
  # FileUtils.rm Dir.glob File.join opts[:outdir], "mothur.*.logfile"
  # FileUtils.rm_r outdir_tmp
  FileUtils.mkdir_p chimera_dir
  FileUtils.mv Dir.glob(chimera_details), chimera_dir
end

##########
# clean up
######################################################################
