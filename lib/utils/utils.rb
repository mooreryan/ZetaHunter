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
end
