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

require_relative "../abort_if/abort_if"
require "set"

module Utils
  @@usr_otu_num = 1
  NON_GAPS = Set.new %w[A a C c T t G g U u N n]

  # def new_hash_of_arrays
  #   Hash.new { |hash, key| hash[key] = [] unless hash.has_key?(k) }
  # end

  def has_ambiguous_bases? seq
    seq.include?("N") || seq.include?("n")
  end

  def flag_to_s flag
    str = []

    if FLAG_CHIMERA & flag != 0
      str << "CHIMERA"
    end

    if FLAG_OG_GTE_97 & flag != 0
      str << "OG_GTE_97"
    end

    if FLAG_OG_LT_97 & flag != 0
      str << "OG_LT_97"
    end

    if FLAG_SINGLETON & flag != 0
      str << "SINGLETON"
    end

    if FLAG_DOUBLETON & flag != 0
      str << "DOUBLETON"
    end

    if FLAG_LARGE_FRAGMENT & flag != 0
      str << "FRAGMENT_SMALL"
    end

    if FLAG_SMALL_FRAGMENT & flag != 0
      str << "FRAGMENT_LARGE"
    end

    if FLAG_AMBIGUOUS_BASES & flag != 0
      str << "AMBIGUOUS_BASES"
    end

    if str.empty?
      "0"
    else
      str.sort.join ","
    end
  end

  # Flags the CLEAN id and the regular one
  def update_seq_flag seqid, flag
    # AbortIf::Abi.logger.info {
    #   "Flagging #{seqid} as #{flag.to_s(2)}"
    # }

    # If they are the same, the second one won't do anything
    SEQ_FLAG[seqid] |= flag
    SEQ_FLAG[clean(seqid)] |= flag
  end

  def remove_all_gaps seq
    seq.gsub /\p{^Alpha}/, ""
  end

  def log_cmd logger, cmd
    logger.debug "Running: #{cmd}"
  end

  def escape_dashes str
    str.gsub '-', '\-'
  end

  def dash_to_underscore str
    str.gsub '-', '_'
  end

  def has_dash? str
    str.include? "-"
  end

  def clean str
    str.gsub(/[^\p{Alnum}_]+/, "_").gsub(/_+/, "_")
  end

  def gap? base
    base == "-" || base == "."
  end

  def get_gap_posns seq
    these_gap_posns = []

    seq.each_char.with_index do |base, idx|
      # Don't use the gap? method here for speed
      is_gap = base == "-" || base == "."

      these_gap_posns << idx if is_gap
    end

    these_gap_posns
  end

  def get_otu_call otu_call_counts
    AbortIf::Abi.assert otu_call_counts

    otu_call = ""
    otu_call_counts.each do |otu, count|
      AbortIf::Abi.assert otu
      AbortIf::Abi.assert count

      unless otu == "USR"
        otu_call = otu
        break
      end
    end

    if otu_call.empty?
      otu_call = "NewZetaOtu#{@@usr_otu_num}"
      @@usr_otu_num += 1
    end

    msg = "Could not determine OTU for #{otu_call_counts}"
    AbortIf::Abi.abort_if otu_call.empty?, msg

    otu_call
  end

  def get_otu_calls ids, db_otu_info, input_ids
    ids.map do |id|
      if db_otu_info.has_key? id
        db_otu_info[id][:otu]
      else
        AbortIf::Abi.assert input_ids.include?(id),
                            "ID '#{id}' is missing from input_ids"

        "USR"
      end
    end
  end

  def get_otu_call_counts otu_calls
    counts = otu_calls.
      group_by(&:itself).
      map { |otu, arr| [otu, arr.count] }.
      sort_by { |otu, count| count }.
      reverse

    AbortIf::Abi.refute counts.empty?, "No count info for %s", otu_calls.inspect

    counts
  end

  # TODO this should take mask lenght and check against that?
  def get_seq_entropy seq, entropy
    AbortIf::Abi.assert seq
    AbortIf::Abi.assert entropy
    # AbortIf::Abi.assert seq.length == entropy.length,
    #        "Seq length was %d should be %d",
    #        seq.length,
    #        entropy.length

    # TODO consider checking length
    # unless seq.length == entropy.length
    #   AbortIf::Abi.logger.warn { sprintf "Seq length was %d. " +
    #                                      "If this is the Zeta mask, " +
    #                                      "it should be %d",
    #                                      seq.length,
    #                                      entropy.length }
    # end

    bases_in_mask = 0
    per_posn_entropy = seq.each_char.map.with_index do |base, idx|
      if gap? base
        0
      else
        bases_in_mask += 1
        entropy[idx]
      end
    end

    this_entropy = per_posn_entropy.reduce(:+)
    total_entropy = entropy.reduce(:+).to_f
    perc_total_entropy = (this_entropy / total_entropy * 100).round(1)
    perc_bases_in_mask =
      (bases_in_mask / MASK_LEN.to_f * 100).round(1)

    { perc_total_entropy: perc_total_entropy,
      perc_bases_in_mask: perc_bases_in_mask }
  end

  def self.process_input_aln(file:, seq_ids:, seqs:, gap_posns:, lib: 0)
    FastaFile.open(file, "rt").each_record do |head, seq|
      msg = "Seq '#{head}' in file '#{file}' has length " +
            "'#{seq.length}'. Should be '#{Const::SILVA_ALN_LEN}'"
      AbortIf::Abi.abort_unless seq.length == Const::SILVA_ALN_LEN, msg

      id = clean head.split(" ").first

      if has_ambiguous_bases? seq
        update_seq_flag id, FLAG_AMBIGUOUS_BASES
      end

      msg = "Seq ID '#{id}' is repeated in file '#{file}'. Previous rec was #{seqs[id]}"
      AbortIf::Abi.abort_if seq_ids.include?(id), msg

      seq_ids << id

      AbortIf::Abi.abort_if seqs.has_key?(id), msg

      seqs[id] =  { orig: rna_to_dna(seq), lib: lib }

      AbortIf::Abi.abort_if seqs[id][:orig].match(/U/i),
                            "Seq '#{id}' looks like RNA, should be DNA"

      AbortIf::Abi.abort_if seqs.empty? { "Did not find any seqs in file '#{file}'" }

      update_gap_posns gap_posns, seq
    end
  end

  def self.process_input_alns(files:, seq_ids:, seqs:, gap_posns:)
    files.each_with_index do |fname, idx|
      Utils.process_input_aln file: fname,
                              seq_ids: seq_ids,
                              seqs: seqs,
                              gap_posns: gap_posns,
                              lib: "S#{idx+1}"
    end

    AbortIf::Abi.abort_if seq_ids.empty?,
                          "Did not find any input seqs"
  end

  def read_mask fname
    mask_positions = []

    FastaFile.open(fname, "rt").each_record do |head, seq|
      msg = "Seq '#{head}' in file '#{fname}' has length " +
            "'#{seq.length}'. Should be '#{Const::SILVA_ALN_LEN}'"
      AbortIf::Abi.abort_unless seq.length == Const::SILVA_ALN_LEN, msg

      msg = "Improper characters in the mask in file '#{fname}'"
      AbortIf::Abi.abort_if seq.match(/[^-*~\.]/), msg

      seq.each_char.with_index do |char, idx|
        mask_positions << idx if char == "*"
      end
    end

    AbortIf::Abi.logger.info { "Num mask bases: #{mask_positions.count}" }

    mask_positions
  end

  # also cleans the acc.
  def read_otu_metadata fname
    db_otu_info = {}

    File.open(fname, "rt").each_line do |line|
      unless line.start_with? "#"
        acc, otu, clone, num = line.chomp.split "\t"

        # at some point the acc for the db seqs are getting cleaned,
        # so need to clean this too. TODO find where that is
        acc = clean acc

        msg = "Seq ID '#{acc}' is repeated in file '#{fname}'"
        AbortIf::Abi.abort_if db_otu_info.has_key?(acc), msg

        db_otu_info[acc] = { otu: otu, clone: clone, num: num.to_i }
      end
    end

    db_otu_info
  end

  def rna_to_dna seq
    seq.gsub(/U/, "T").gsub(/u/, "t")
  end

  def update_gap_posns gap_posns, seq
    gap_posns << get_gap_posns(seq)
  end

  def update_with_degapped_and_mask seqs, mask, shared_gap_posns
    seqs.each do |head, info|
      AbortIf::Abi.assert head
      AbortIf::Abi.assert info
      AbortIf::Abi.assert_keys info, :orig

      orig = info[:orig]
      # masked = ""
      # degapped = ""
      # orig.each_char.with_index do |base, posn|
      #   masked << base if mask.include? posn
      #   degapped << base if shared_gap_posns.include? posn
      # end

      # this way is faster
      masked = mask.map { |idx| orig[idx] }.join
      degapped = shared_gap_posns.map { |idx| orig[idx] }.join

      AbortIf::Abi.assert masked.length == mask.length
      AbortIf::Abi.assert degapped.length == shared_gap_posns.count

      seqs[head][:masked] = masked
      seqs[head][:degapped] = degapped

      AbortIf::Abi.assert_keys seqs.first.last, :masked, :degapped
    end
  end

  def is_outgroup? db_otu_info, seq_id
    db_otu_info.has_key?(seq_id) && db_otu_info[seq_id][:otu] == "OG"
  end

  def emergency_brake!
    warn "EMERGENCY BRAKE ENGAGED!"
    exit
  end

  def get_cluster_method method
    if method == "furthest"
      return "fn"
    elsif method == "average"
      return "an"
    elsif method == "nearest"
      return "nn"
    else
      AbortIf::Abi.abort_if true, "--cluster-method must be one of furthest, " +
                                  "average, or nearest. Got: #{method}"
    end
  end

  def check_for_error mothur_log
    AbortIf::Abi.abort_if(File.read(mothur_log).include?("ERROR"),
                          "Mothur exited with an error. " +
                          "Check #{mothur_log} for details.")
  end

  def self.write_sample_to_file_name_map library_to_fname_f, infiles
    File.open(library_to_fname_f, "w") do |f|
      f.puts %w[#Sample FileName].join "\t"

      infiles.each_with_index do |fname, idx|
        f.puts ["S#{idx+1}", fname].join "\t"
      end
    end

    AbortIf::Abi.logger.debug { "Sample to fname map: #{library_to_fname_f}" }
  end

  def self.which_gunzip
    gunzip = `which gunzip`.chomp
    AbortIf::Abi.abort_unless $?.exitstatus.zero?, "Cannot find gunzip command"

    gunzip
  end

  def self.ungzip_if_needed infiles, outdir
    inaln_info = infiles.map { |fname| File.parse_fname fname }

    gunzip = self.which_gunzip

    new_infiles = infiles.map.with_index do |fname, idx|
      if fname.match(/.gz$/)
        inaln_not_gz = File.join outdir, "#{inaln_info[idx][:base]}.not_gz.fa"
        cmd = "#{gunzip} -c #{fname} > #{inaln_not_gz}"
        log_cmd AbortIf::Abi.logger, cmd
        Process.run_it! cmd

        inaln_not_gz
      else
        fname
      end
    end

    new_infiles
  end

  def self.get_entropy_for_seqs entropy, sequences
    seq_entropys = {}
    seq_entropy = 0

    sequences.each do |head, seqs|
      msg = "Seq '#{head}' is repeated"
      AbortIf::Abi.abort_if seq_entropys.has_key?(head), msg
      AbortIf::Abi.refute seqs[:masked].empty?, "seqs[:masked] is empty"

      seq_entropy = get_seq_entropy seqs[:masked], entropy
      seq_entropys[head] = seq_entropy

      if seq_entropy[:perc_total_entropy] < SMALL_FRAGMENT_CUTOFF
        update_seq_flag head, FLAG_SMALL_FRAGMENT
      elsif seq_entropy[:perc_total_entropy] < LARGE_FRAGMENT_CUTOFF
        update_seq_flag head, FLAG_LARGE_FRAGMENT
      end
    end

    seq_entropys
  end

  def self.unzip_silva_gold_aln outdir
    silva_gold_aln = File.join outdir, "silva.gold.align"
    cmd = "#{self.which_gunzip} -c #{Const::SILVA_GOLD_ALN_GZ} > #{silva_gold_aln}"
    log_cmd AbortIf::Abi.logger, cmd
    Process.run_it! cmd

    AbortIf::Abi.abort_unless_file_exists silva_gold_aln
    silva_gold_aln
  end

  def self.redirect_log mothur_log
    ">> #{mothur_log} 2>&1"
  end

  def self.run_uchime infiles
    infiles.each do |fname|
      params = "fasta=#{fname}, " +
               "reference=#{SILVA_GOLD_ALN}, " +
               "outputdir=#{WORKING_D}, " +
               "processors=#{THREADS}"

      cmd = "#{MOTHUR} " +
            "'#chimera.uchime(#{params})' " +
            "#{self.redirect_log MOTHUR_LOG}"

      log_cmd AbortIf::Abi.logger, cmd
      Process.run_it! cmd

      check_for_error MOTHUR_LOG
    end
  end

  def self.read_uchime_chimeras infiles, chimeric_ids
    infiles.each do |fname|

      base = File.basename(fname, File.extname(fname))
      uchime_ids = File.join WORKING_D, "#{base}.ref.uchime.accnos"

      File.open(uchime_ids, "rt").each_line do |line|
        id = line.chomp
        chimeric_ids.store_in_array id, "uchime"

        update_seq_flag id, FLAG_CHIMERA
      end
    end
  end

  def self.write_chimeric_seqs chimeric_ids, chimeric_seqs_outf, input_seqs
    File.open(chimeric_seqs_outf, "w") do |f|
      f.puts %w[#SeqID Sample ChimeraChecker].join "\t"

      chimeric_ids.sort_by { |k, v| k }.each do |id, software|
        clean_id = clean(id)
        AbortIf::Abi.assert_keys input_seqs, clean_id
        sample = input_seqs[clean_id][:lib]
        f.puts [clean_id, sample, software.sort.join(",")].join "\t"
      end
    end

    AbortIf::Abi.logger.info { "Chimeric seqs written to #{chimeric_seqs_outf}" }
  end

  def self.unalign_seqs_from_file inaln, outfile
    File.open(outfile, "w") do |f|
      FastaFile.open(inaln).each_record_fast do |head, seq|
        f.puts ">#{clean(head.split(" ").first)}"
        f.puts remove_all_gaps(seq)

      end
    end

    AbortIf::Abi.logger.debug { "Aligned DB seqs: #{inaln}" }
    AbortIf::Abi.logger.debug { "Unaligned DB seqs: #{outfile}" }
  end

  def self.unalign_seqs_from_input_seqs input_seqs, outfile
    File.open(outfile, "w") do |f|
      input_seqs.each do |head, seq|
        f.puts ">#{head}"
        f.puts remove_all_gaps(seq[:orig])
      end
    end
  end

  def self.build_sortmerna_idx
    AbortIf::Abi.abort_unless_file_exists DB_SEQS_UNALN

    cmd = "#{INDEXDB_RNA} " +
          "--ref #{DB_SEQS_UNALN},#{SORTMERNA_IDX}"

    log_cmd AbortIf::Abi.logger, cmd
    Process.run_it! cmd
  end

  def self.run_sortmerna input_unaln, sortme_blast
    cmd = "#{SORTME_RNA} " +
          "-a #{THREADS} " +
          "--ref #{DB_SEQS_UNALN},#{SORTMERNA_IDX} " +
          "--reads #{input_unaln} " +
          "--aligned #{sortme_blast} " +
          "--blast '1 qcov' " +
          "--num_alignments 0"

    # sort me rna adds .blast to the output base
    sortme_blast += ".blast"

    log_cmd AbortIf::Abi.logger, cmd
    Process.run_it! cmd
    AbortIf::Abi.logger.debug { "SortMeRNA blast: #{sortme_blast}" }

    sortme_blast
  end

  def self.read_sortme_blast sortme_blast
    closed_ref_otus = {}

    File.open(sortme_blast, "rt").each_line do |line|
      user_seq, db_seq_hit, pid, *rest = line.chomp.split "\t"

      pid = pid.to_f
      qcov = rest.last.to_f

      if qcov >= MIN_SORTMERNA_QCOV
        insert_new_entry =
          (closed_ref_otus.has_key?(user_seq) &&
           closed_ref_otus[user_seq][:pid] < pid) || # current hit is a better hit
          !closed_ref_otus.has_key?(user_seq)

        if insert_new_entry
          closed_ref_otus[user_seq] = { hit: db_seq_hit,
                                        pid: pid,
                                        qcov: qcov }
        end
      end
    end

    closed_ref_otus
  end

  def self.write_closest_ref_seqs_and_otu_calls closest_seqs_outf,
                                                closed_ref_otus,
                                                masked_input_seq_entropy,
                                                input_seqs,
                                                db_otu_info,
                                                outgroup_names

    closest_to_outgroups = []
    cluster_these_user_seqs = {}

    File.open(closest_seqs_outf, "w") do |close_f|
      File.open(DISTANCE_BASED_OTUS_F, "w") do |otu_f|
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
          begin
            close_f.puts [user_seq,
                          input_seqs[user_seq][:lib],
                          db_otu_info[info[:hit]][:otu],
                          perc_total_entropy,
                          perc_bases_in_mask,
                          info[:hit],
                          info[:pid],
                          info[:qcov]].join "\t"
          rescue NoMethodError => e
            p "ERROR!!!"
            p e.backtrace
            p [user_seq, info.keys, input_seqs.keys, db_otu_info.keys, info[:hit]]
            abort
          end

          if outgroup_names.include? info[:hit] # is nearest an outgroup
            if info[:pid] >= 97.0
              update_seq_flag user_seq, FLAG_OG_GTE_97
            else
              update_seq_flag user_seq, FLAG_OG_LT_97
            end

            closest_to_outgroups << user_seq # is output
          end

          # Literally everything that is within 3% of a DB seq will be
          # written here now, even if it is to an outgroup. The flag
          # will explain things.
          if info[:pid] < 97.0 # will be clustered later
            AbortIf::Abi.assert input_seqs.has_key? user_seq
            cluster_these_user_seqs[user_seq] = input_seqs[user_seq] # is output
          else # is a good closed reference call
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

    AbortIf::Abi.logger.debug { "Closest DB seqs: #{closest_seqs_outf}" }
    AbortIf::Abi.logger.debug { "Distance based OTU calls written " +
                                "to #{DISTANCE_BASED_OTUS_F}" }

    return [closest_to_outgroups, cluster_these_user_seqs]
  end

  def self.write_cluster_me_file cluster_me_outf, cluster_these_user_seqs, db_seqs
    File.open(cluster_me_outf, "w") do |f|
      cluster_these_user_seqs.each do |head, seqs|
        f.printf ">%s\n%s\n", head, seqs[:masked]
      end

      db_seqs.each do |head, seqs|
        f.printf ">%s\n%s\n", head, seqs[:masked]
      end
    end

    AbortIf::Abi.logger.info { "We will cluster this file: #{cluster_me_outf}" }
  end

  def self.run_mothur_distance cluster_me_f
    cmd = "#{MOTHUR} " +
          "'#dist.seqs(fasta=#{cluster_me_f}, " +
          "outputdir=#{TMP_OUT_D}, " +
          "output=lt, " +
          "processors=#{THREADS})' " +
          "#{Utils.redirect_log MOTHUR_LOG}"

    log_cmd AbortIf::Abi.logger, cmd
    Process.run_it! cmd

    check_for_error MOTHUR_LOG
  end

  def self.run_mothur_cluster cluster_me_dist
    cmd = "#{MOTHUR} " +
          "'#cluster(phylip=#{cluster_me_dist}, " +
          "method=#{CLUSTER_METHOD})' " +
          "#{Utils.redirect_log MOTHUR_LOG}"

    log_cmd AbortIf::Abi.logger, cmd
    Process.run_it! cmd

    check_for_error MOTHUR_LOG
  end

  def self.run_mothur_get_otu_list cluster_me_list
    cmd = "#{MOTHUR} '#get.otulist(list=#{cluster_me_list})' " +
          "#{Utils.redirect_log MOTHUR_LOG}"
    log_cmd AbortIf::Abi.logger, cmd
    Process.run_it! cmd

    check_for_error MOTHUR_LOG
  end

  def self.find_otu_file otu_file_base, otu_dist
    otu_file = ""
    # %w[03 02 01].each do |pid|
    #   otu_file = "#{otu_file_base}.#{pid}.otu"
    (0..otu_dist).map do |n|
      n >= 10 ? n.to_s : "0#{n}"
    end.reverse.each do |pid|
      otu_file = "#{otu_file_base}.#{pid}.otu"
      break if File.exists? otu_file
      AbortIf::Abi.logger.debug { "OTU file #{otu_file} not found, checking the next one." }
    end

    AbortIf::Abi.abort_unless_file_exists otu_file
    AbortIf::Abi.logger.info { "For OTUs, using #{otu_file}" }

    otu_file
  end

  def self.assign_denovo_otus otu_file,
                              db_otu_info,
                              input_ids,
                              input_seqs,
                              closest_to_outgroups,
                              masked_input_seq_entropy,
                              closed_ref_otus

    seqs_in_denovo_otus_file = []

    File.open(DENOVO_OTUS_F, "w") do |f|
      f.puts %w[#SeqID Sample OTU PercEntropy PercMaskedBases OTUComp].join "\t"

      # This file contains seqs from the clusters_these_user_seqs
      # array only. Not closest_to_outgroups (from the
      # write_closest_ref_seqs_and_otu_calls metdod).
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

          # TODO if an otu contains at least one seq closest to a non
          # zeta, flag all sequences in that otu as possibly not zetas

          if otu_size == 1
            update_seq_flag id, FLAG_SINGLETON
          elsif otu_size == 2
            update_seq_flag id, FLAG_DOUBLETON
          end

          # Now we are including these in the otu calls files. The
          # flag will explain the risk.

          AbortIf::Abi.assert_keys masked_input_seq_entropy, id
          perc_entropy = masked_input_seq_entropy[id]
          seqs_in_denovo_otus_file << id
          f.puts [id,
                  sample,
                  otu_call,
                  perc_entropy[:perc_total_entropy],
                  perc_entropy[:perc_bases_in_mask],
                  otu_call_counts.inspect].join "\t"
        end
      end
    end

    AbortIf::Abi.logger.info { "de novo OTU calls written to #{DENOVO_OTUS_F}" }
  end

  def self.write_final_otu_calls
    File.open(FINAL_OTU_CALLS_F, "w") do |f|
      f.puts ["#SeqID",
              "Sample",
              "OTU",
              "PercEntropy",
              "PercMaskedBases",
              "Flag"].join "\t"

      File.open(DISTANCE_BASED_OTUS_F, "rt").each_line do |line|
        unless line.start_with? "#"
          seq, sample, otu, ent, masked, hit, *rest = line.chomp.split "\t"

          AbortIf::Abi.logger.debug { "Read #{seq} from closed ref otu file" }

          flag = flag_to_s SEQ_FLAG[seq]

          if otu == "OG"
            f.puts [seq, sample, hit, ent, masked, flag].join "\t"
          else
            f.puts [seq, sample, otu, ent, masked, flag].join "\t"
          end
        end
      end

      File.open(DENOVO_OTUS_F, "rt").each_line do |line|
        unless line.start_with? "#"
          seq, sample, otu, ent, masked, *rest = line.chomp.split "\t"

          AbortIf::Abi.logger.debug { "Read #{seq} from de novo otu file" }

          flag = flag_to_s SEQ_FLAG[seq]

          f.puts [seq, sample, otu, ent, masked, flag].join "\t"
        end
      end
    end

    AbortIf::Abi.logger.info { "Final OTU calls written to #{FINAL_OTU_CALLS_F}" }
  end

  def self.write_biom_file infiles
    File.open(BIOM_F, "w") do |f|
      sample_arr = infiles.map.with_index do |_, idx|
        "S#{idx+1}"
      end

      otu_counts = {}
      f.puts ["#OTU ID", sample_arr].flatten.join "\t"
      File.open(FINAL_OTU_CALLS_F).each_line do |line|
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

  def self.clean_up sortme_blast, debug
    files_to_delete = []

    files_to_delete << Dir.glob(File.join ZH_PWD_DIR, "*.tmp.uchime_formatted")
    files_to_delete << Dir.glob(File.join WORKING_D, "mothur.*.logfile")
    files_to_delete << Dir.glob(File.join ZH_PWD_DIR, "mothur.*.logfile")

    files_to_delete.flatten.uniq.each do |fname|
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

    # For sleep command, see
    # https://github.com/mooreryan/ZetaHunter/issues/37
    sleep 2
    begin
      FileUtils.rm_r TMP_OUT_D, secure: true
    rescue Errno::ENOTEMPTY => e
      AbortIf::Abi.logger.warn do
        "Got Errno::ENOTEMPTY when trying to delete " +
          "#{TMP_OUT_D}. Not deleting it. Error: " +
          "#{e.inspect}"
      end
    rescue SystemCallError => e
      AbortIf::Abi.logger.warn do
        "Could not delete '#{fname}'. " +
          "This likely is not an issue, but your outdir might " +
          "be messy. Error: #{e.inspect}"
      end
    end

    # unless debug # only delete if no debug flag is passed
    #   FileUtils.rm Dir.glob File.join ZH_PWD_DIR, "*.tmp.uchime_formatted"

    #   FileUtils.rm Dir.glob File.join WORKING_D, "mothur.*.logfile"
    #   FileUtils.rm Dir.glob File.join ZH_PWD_DIR, "mothur.*.logfile"
    # end

    FileUtils.mv Dir.glob(CHIMERA_DETAILS), CHIMERA_D

    FileUtils.mv(sortme_blast,
                 File.join(MISC_DIR,
                           "#{BASE}.all_sortmerna_db_hits.txt"))

    FileUtils.mv ZH_LOG, ZH_LOG_FINAL

    # Move entire contents of the working directory (that haven't yet
    # been deleted) into the final directory

    FileUtils.mv Dir.glob(File.join(WORKING_D, "*")),
                 FINAL_OUT_D

    FileUtils.rm_r WORKING_D, secure: true
  end

  def self.create_needed_dirs

    AbortIf::Abi.abort_if File.exists?(FINAL_OUT_D),
                          "Outdir '#{FINAL_OUT_D}' already exists. " +
                          "Choose a different outdir."

    Dir.try_mkdir FINAL_OUT_D

    Dir.try_mkdir BIOM_D
    Dir.try_mkdir CYTOSCAPE_D
    Dir.try_mkdir DANGEROUS_D
    Dir.try_mkdir LOG_D
    Dir.try_mkdir MISC_DIR
    Dir.try_mkdir OTU_CALLS_D

    # This dir may have already been made in a previous call to
    # simple_clea_and_copy
    begin
      FileUtils.mkdir_p TMP_OUT_D
    rescue Errno::EEXIST => e
      AbortIf::Abi.logger.debug { "#{new_dir} already exists. No action taken" }
    end

    Dir.try_mkdir CHIMERA_D
  end

  def self.write_cytoscape_files
    sample_names = []
    samples = []

    File.open(NODES_F, "w") do |f|
      f.puts %w[otu count].join "\t"

      File.open(BIOM_F).each_line do |line|
        if line.start_with? "#"
          _, *sample_names = line.chomp.split "\t"
        else
          otu, *counts = line.chomp.split "\t"

          counts = counts.map { |n| n.to_i }

          f.puts [otu, counts.reduce(:+)].join "\t"

          counts.each_with_index do |count, idx|
            # if a sample has zero count for all OTU, it will have nil
            # for that index in the counts ary. (See below) This can
            # happen if every seq in the sample is not a zeta
            if count > 0
              if samples[idx].nil?
                samples[idx] = [otu]
              else
                samples[idx] << otu
              end
            end
          end
        end
      end
    end

    AbortIf::Abi.logger.info { "Wrote #{NODES_F}" }

    File.open(EDGES_F, "w") do |f|
      f.puts %w[node1 node2 sample].join "\t"

      samples.each_with_index do |otus, idx|
        # if a sample has 0 count for all OTUs the otus ary will be
        # nil
        unless otus.nil?
          sample_name = sample_names[idx]

          if otus.count == 1
            otu = otus[0]
            f.puts [otu, otu, sample_name].join "\t"
          end

          otus.combination(2).each do |otu1, otu2|
            f.puts [otu1, otu2, sample_name].join "\t"
          end
        end
      end
    end

    AbortIf::Abi.logger.info { "Wrote #{EDGES_F}" }
  end
end
