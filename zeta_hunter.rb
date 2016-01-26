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

cmd = "rm -r #{opts[:outdir]}"
log_cmd logger, cmd
Process.run_it cmd

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
  logger.debug { "Mask: #{mask.inspect}" }
end

Time.time_it("Update shared gap posns with db seqs", logger) do
  process_input_aln file: opts[:db_seqs],
                    seq_ids: db_seq_ids,
                    seqs: db_seqs,
                    gap_posns: gap_posns
end


Time.time_it("Read outgroups", logger) do
  File.open(OUTGROUPS).each_line do |line|
    outgroup_names << line.chomp
  end
end

####################
# read provided info
######################################################################


Time.time_it("Remove all gaps", logger) do
  cmd = "ruby #{REMOVE_ALL_GAPS} #{opts[:inaln]} > #{inaln_nogaps}"
  log_cmd logger, cmd
  Process.run_it! cmd
end

######################################################################
# slay the chimeras
###################

run = nil
# run = true

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
    chimeric_ids << id
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
    chimeric_ids << id
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
    chimeric_ids << id
  end
end

chimeric_ids.each do |id|
  logger.debug { "#{id} was flagged as chimeric" }
end

###################
# slay the chimeras
######################################################################

######################################################################
# cluster
#########

Time.time_it("Write combined fasta", logger) do
  File.open(cluster_me, "w") do |f|
    input_seqs.each { |head, seq| f.printf ">%s\n%s\n", head, seq }
    db_seqs.each { |head, seq| f.printf ">%s\n%s\n", head, seq }
  end
end

Time.time_it("Distance", logger) do
  cmd = "#{MOTHUR} " +
        "'#dist.seqs(fasta=#{cluster_me}, " +
        "outputdir=#{outdir_tmp}, " +
        "output=lt, " +
        "processors=#{opts[:threads]})'"

  log_cmd logger, cmd
  Process.run_it! cmd
end

Time.time_it("Cluster", logger) do
  cmd = "#{MOTHUR} " +
        "'#cluster(phylip=#{cluster_me_dist})'"

  log_cmd logger, cmd
  Process.run_it! cmd
end

Time.time_it("Get OTU list", logger) do
  cmd = "#{MOTHUR} '#get.otulist(list=#{cluster_me_list})'"
  log_cmd logger, cmd
  Process.run_it! cmd
end


#########
# cluster
######################################################################

FileUtils.rm Dir.glob File.join File.dirname(__FILE__), "mothur.*.logfile"
FileUtils.rm Dir.glob File.join File.dirname(__FILE__), "formatdb.log"
FileUtils.rm Dir.glob File.join TEST_DIR, "*.tmp.uchime_formatted"
FileUtils.rm Dir.glob File.join opts[:outdir], "mothur.*.logfile"
