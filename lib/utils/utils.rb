require_relative "../abort_if/abort_if"

module Utils
  @@usr_otu_num = 1

  # def new_hash_of_arrays
  #   Hash.new { |hash, key| hash[key] = [] unless hash.has_key?(k) }
  # end

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
    base.match /[^ACTGUN]/i
  end

  def get_gap_posns seq
    # these_gap_posns = Set.new
    # seq.each_char.with_index do |base, posn|
    #   these_gap_posns << posn if gap?(base)
    # end

    these_gap_posns = []

    seq.each_char.with_index do |base, idx|
      these_gap_posns << idx if gap?(base)
    end

    these_gap_posns
  end

  def get_otu_call otu_call_counts
    assert otu_call_counts

    otu_call = ""
    otu_call_counts.each do |otu, count|
      assert otu
      assert count

      unless otu == "USR"
        otu_call = otu
        break
      end
    end

    if otu_call.empty?
      otu_call = "USR-OTU-#{@@usr_otu_num}"
      @@usr_otu_num += 1
    end

    refute otu_call.empty?,
           "Could not determine OTU for %s",
           otu_call_counts

    otu_call
  end

  def get_otu_calls ids, db_otu_info, input_ids
    ids.map do |id|
      if db_otu_info.has_key? id
        db_otu_info[id][:otu]
      else
        unless input_ids.include? id
          warn "#{id} is not in #{db_otu_info.keys.inspect}"
          abort "ERROR: input_ids missing #{id}\n#{input_ids.inspect}"
        end
        assert_includes input_ids, id
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

    refute counts.empty?, "No count info for %s", otu_calls.inspect

    counts
  end

  def get_seq_entropy seq, entropy
    assert seq
    assert entropy
    assert seq.length == entropy.length,
           "Seq length was %d should be %d",
           seq.length,
           entropy.length

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

  def process_input_aln(file:, seq_ids:, seqs:, gap_posns:, lib: 0)
    FastaFile.open(file, "rt").each_record do |head, seq|
      assert_seq_len seq, head

      id = clean head.split(" ").first

      refute_includes seq_ids, id
      seq_ids << id

      refute_has_key seqs, id
      seqs[id] =  { orig: rna_to_dna(seq), lib: lib }

      refute seqs[id][:orig].match(/U/i)

      update_gap_posns gap_posns, seq
    end
  end

  def read_mask fname
    mask_positions = []

    FastaFile.open(fname, "rt").each_record do |head, seq|
      assert_seq_len seq, "Mask"

      refute seq.match(/[^-*~\.]/), "Improper characters in the mask"

      seq.each_char.with_index do |char, idx|
        mask_positions << idx if char == "*"
      end
    end

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

        assert !db_otu_info.has_key?(acc),
               "%s is repeated in %s",
               acc,
               fname

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
      assert head
      assert info
      assert_keys info, :orig

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

      assert masked.length == mask.length
      assert degapped.length == shared_gap_posns.count

      seqs[head][:masked] = masked
      seqs[head][:degapped] = degapped
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
end
