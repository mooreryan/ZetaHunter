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
  mask: MASK
}

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

# containers

chimeric_ids = Set.new
input_seqs = {}
db_otu_info  = {}
input_ids    = Set.new
mask         = []
gap_posns = []

# mothur params
mothur_params = "fasta=#{opts[:inaln]}, " +
                "reference=#{GOLD_ALN}, " +
                "outputdir=#{opts[:outdir]}, " +
                "processors=#{opts[:threads]}"

Time.time_it("Create needed directories", logger) do
  FileUtils.mkdir_p opts[:outdir]
  FileUtils.mkdir_p outdir_tmp
end

Time.time_it("Process input data", logger) do
  FastaFile.open(opts[:inaln]).each_record do |head, seq|
    assert_seq_len seq, head

    id = head.split(" ")

    # track ids
    refute_includes input_ids, id
    input_ids << id

    # read seq into memory
    refute_has_key input_seqs, id
    input_seqs[id] = seq

    # gap posistions in input data
    these_gap_posns = Set.new
    seq.each_char.with_index do |base, posn|
      these_gap_posns << posn if gap?(base)
    end

    gap_posns << these_gap_posns
  end
end

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

# run = nil
run = true

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
