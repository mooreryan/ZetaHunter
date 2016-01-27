require_relative File.join "lib", "lib_helper.rb"

include Const
include Assert
include Utils

Process.extend CoreExtensions::Process
Time.extend CoreExtensions::Time
File.extend CoreExtensions::File

logger = Logger.new STDERR

this_dir = File.dirname(__FILE__)

opts = {
  inaln: TEST_ALN,
  outdir: TEST_OUTDIR,
  threads: 2,
  db_otu_info: DB_OTU_INFO,
  mask: MASK,
  db_seqs: DB_SEQS,
}

######################################################################
# FOR TEST ONLY -- remove outdir before running
###############################################

# cmd = "rm -r #{opts[:outdir]}"
# log_cmd logger, cmd
# Process.run_it cmd

run = nil
# run = true

###############################################
# FOR TEST ONLY -- remove outdir before running
######################################################################


assert_file opts[:inaln]

inaln_info = File.parse_fname opts[:inaln]

outdir_tmp = File.join opts[:outdir], "tmp"

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
cluster_me_list = File.join outdir_tmp, "cluster_me.phylip.an.list"
otu_file_base = File.join outdir_tmp, "cluster_me.phylip.an.0"
otu_file = ""

otu_calls_f =
  File.join opts[:outdir], "#{inaln_info[:base]}.otu_calls.txt"

chimeric_seqs =
  File.join opts[:outdir], "#{inaln_info[:base]}.dangerous_seqs.txt"


# containers

chimeric_ids = Set.new
db_otu_info  = {}
db_seq_ids = Set.new
db_seqs = {}
gap_posns = []
input_ids    = Set.new
input_seqs = {}
mask         = []
outgroup_names = Set.new
otu_info = []


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

Time.time_it("Read db OTU metadata", logger) do
  db_otu_info = read_otu_metadata opts[:db_otu_info]
  logger.debug { "DB OTU INFO: #{db_otu_info.inspect}" }
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

Time.time_it("Remove all gaps", logger) do
  cmd = "ruby #{REMOVE_ALL_GAPS} #{opts[:inaln]} > #{inaln_nogaps}"
  log_cmd logger, cmd
  Process.run_it! cmd
end

######################################################################
# slay the chimeras
###################

Time.time_it("Chimera Slayer", logger, run) do
  # in must be same length as reference
  cmd = "#{MOTHUR} " +
        "'#chimera.slayer(#{mothur_params})'"
  log_cmd logger, cmd
  Process.run_it! cmd
end

Time.time_it("Read slayer chimeras", logger, run) do
  File.open(slayer_ids).each_line do |line|
    id = line.chomp
    logger.debug { "Chimera Slayer flagged #{id}" }
    chimeric_ids << [id, "ChimeraSlayer"]
  end
end

Time.time_it("Uchime", logger, run) do
  cmd = "#{MOTHUR} " +
        "'#chimera.uchime(#{mothur_params})'"
  log_cmd logger, cmd
  Process.run_it! cmd
end

Time.time_it("Read uchime chimeras", logger, run) do
  File.open(uchime_ids).each_line do |line|
    id = line.chomp
    logger.debug { "Uchime flagged #{id}" }
    chimeric_ids << [id, "uchime"]
  end
end

Time.time_it("Pintail", logger, run) do
  cmd = "#{MOTHUR} " +
        "'#chimera.pintail(fasta=#{opts[:inaln]}, " +
        "template=#{GOLD_ALN}, " +
        "conservation=#{SILVA_FREQ}, " +
        "quantile=#{SILVA_QUAN}, " +
        "outputdir=#{opts[:outdir]}, " +
        "processors=#{opts[:threads]})'"
  log_cmd logger, cmd
  Process.run_it! cmd
end

Time.time_it("Read Pintail chimeras", logger, run) do
  File.open(pintail_ids).each_line do |line|
    id = line.chomp
    logger.debug { "Pintail flagged #{id}" }
    chimeric_ids << [id, "Pintail"]
  end
end

Time.time_it("Write chimeric seqs", logger) do
  File.open(chimeric_seqs, "w") do |f|
    chimeric_ids.each do |id, software|
      f.puts [id, software].join "\t"
      logger.debug { "#{id} was flagged as chimeric by #{software}" }
    end
  end

  logger.info { "Chimeric seqs written to #{chimeric_seqs}" }
end

###################
# slay the chimeras
######################################################################

######################################################################
# cluster
#########

run = true
Time.time_it("Write masked, combined fasta", logger, run) do
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

Time.time_it("Distance", logger, run) do
  cmd = "#{MOTHUR} " +
        "'#dist.seqs(fasta=#{cluster_me}, " +
        "outputdir=#{outdir_tmp}, " +
        "output=lt, " +
        "processors=#{opts[:threads]})'"

  log_cmd logger, cmd
  Process.run_it! cmd
end

Time.time_it("Cluster", logger, run) do
  cmd = "#{MOTHUR} " +
        "'#cluster(phylip=#{cluster_me_dist})'"

  log_cmd logger, cmd
  Process.run_it! cmd
end

Time.time_it("Get OTU list", logger, run) do
  cmd = "#{MOTHUR} '#get.otulist(list=#{cluster_me_list})'"
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

Time.time_it("Assign OTUs", logger) do
  # TODO generate good names for new OTUs
  File.open(otu_calls_f, "w") do |f|
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
        f.puts [otu, id, otu_call, otu_call_counts.inspect].join "\t"
      end
    end
  end
  logger.info { "OTU calls written to #{otu_calls_f}" }
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
end

##########
# clean up
######################################################################
