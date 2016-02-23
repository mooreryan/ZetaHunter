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

if opts[:cluster_method] == "furthest"
  method = "fn"
elsif opts[:cluster_method] == "average"
  method = "an"
elsif opts[:cluster_method] == "nearest"
  method = "nn"
else
  assert false, "problem with --cluster-method"
end

cluster_me_list =
  File.join outdir_tmp, "cluster_me.phylip.#{method}.list"
otu_file_base =
  File.join outdir_tmp, "cluster_me.phylip.#{method}.0"


otu_file = ""

otu_calls_f =
  File.join opts[:outdir], "#{inaln_info[:base]}.otu_calls.txt"

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

######################################################################
# cluster
#########

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

warn "EMERGENCY BRAKE ENGAGED!"
exit

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
