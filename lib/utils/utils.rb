module Utils
  def assert_seq_len seq, name="Sequence"
    assert seq.length == SILVA_ALN_LEN,
           "%s length is %d, but should be %d",
           name,
           seq.length,
           SILVA_ALN_LEN
  end

  def log_cmd logger, cmd
    logger.debug { "Running: #{cmd}" }
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

    otu_call = "NEW_USR_OTU" if otu_call.empty?

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

  def process_input_aln(file:, seq_ids:, seqs:, gap_posns:)
    FastaFile.open(file).each_record do |head, seq|
      assert_seq_len seq, head

      id = head.split(" ").first

      refute_includes seq_ids, id
      seq_ids << id

      refute_has_key seqs, id
      seqs[id] =  { orig: rna_to_dna(seq) }

      refute seqs[id][:orig].match(/U/i)

      update_gap_posns gap_posns, seq
    end
  end

  def read_mask fname
    mask_positions = []

    FastaFile.open(fname).each_record do |head, seq|
      assert_seq_len seq, "Mask"

      refute seq.match(/[^-*~\.]/), "Improper characters in the mask"

      seq.each_char.with_index do |char, idx|
        mask_positions << idx if char == "*"
      end
    end

    mask_positions
  end

  def read_otu_metadata fname
    db_otu_info = {}

    File.open(fname).each_line do |line|
      unless line.start_with? "#"
        acc, otu, clone, num = line.chomp.split "\t"

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
end
