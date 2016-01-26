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
    these_gap_posns = Set.new
    seq.each_char.with_index do |base, posn|
      these_gap_posns << posn if gap?(base)
    end
  end

  def process_input_aln(file:, seq_ids:, seqs:, gap_posns:)
    FastaFile.open(file).each_record do |head, seq|
      assert_seq_len seq, head

      id = head.split(" ").first

      refute_includes seq_ids, id
      seq_ids << id

      refute_has_key seqs, id
      seqs[id] = seq

      update_gap_posns gap_posns, seq
    end
  end


  def read_mask fname
    mask_positions = []

    FastaFile.open(fname).each_record do |head, seq|
      assert_seq_len seq, "Mask"

      assert !seq.match(/[^-*~\.]/), "Improper characters in the mask"

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

  def update_gap_posns gap_posns, seq
    gap_posns << get_gap_posns(seq)
  end
end
