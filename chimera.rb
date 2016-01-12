require_relative File.join "lib", "lib_helper.rb"

def log_cmd logger, cmd
  logger.debug { "Running: #{cmd}" }
end

include Const
include Assert

Process.extend CoreExtensions::Process
Time.extend CoreExtensions::Time
File.extend CoreExtensions::File

logger = Logger.new STDERR

this_dir = File.dirname(__FILE__)

opts = {
  inaln: TEST_ALN,
  outdir: TEST_OUTDIR,
  threads: 2
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
input_ids = Set.new
chimeric_ids = Set.new

# mothur params
mothur_params = "fasta=#{opts[:inaln]}, " +
                "reference=#{GOLD_ALN}, " +
                "outputdir=#{opts[:outdir]}, " +
                "processors=#{opts[:threads]}"

Time.time_it("Create needed directories", logger) do
  FileUtils.mkdir_p opts[:outdir]
  FileUtils.mkdir_p outdir_tmp
end

Time.time_it("Validate input data", logger) do
  FastaFile.open(opts[:inaln]).each_record do |head, seq|
    msg = "Sequence #{head} has length #{seq.length}. " +
          "Should be #{SILVA_ALN_LEN}"
    assert seq.length == SILVA_ALN_LEN, msg

    id = head.split(" ")

    assert !input_ids.include?(id),
           "ID %s is repeated in file %s",
           id,
           opts[:inaln]

    input_ids << id
  end
end

Time.time_it("Remove all gaps", logger) do
  cmd = "ruby #{REMOVE_ALL_GAPS} #{opts[:inaln]} > #{inaln_nogaps}"
  log_cmd logger, cmd
  Process.run_it! cmd
end

######################################################################
# slay the chimeras
###################

Time.time_it("Chimera Slayer", logger) do
  # in must be same length as reference
  cmd = "#{MOTHUR} " +
        "'#chimera.slayer(#{mothur_params})'"
  log_cmd logger, cmd
  Process.run_it! cmd
end

Time.time_it("Read slayer chimeras", logger) do
  File.open(slayer_ids).each_line do |line|
    id = line.chomp
    logger.debug { "Chimera Slayer flagged #{id}" }
    chimeric_ids << id
  end
end

Time.time_it("Uchime", logger) do
  cmd = "#{MOTHUR} " +
        "'#chimera.uchime(#{mothur_params})'"
  log_cmd logger, cmd
  Process.run_it! cmd
end

Time.time_it("Read uchime chimeras", logger) do
  File.open(uchime_ids).each_line do |line|
    id = line.chomp
    logger.debug { "Uchime flagged #{id}" }
    chimeric_ids << id
  end
end

Time.time_it("Pintail", logger) do
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

Time.time_it("Read Pintail chimeras", logger) do
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
