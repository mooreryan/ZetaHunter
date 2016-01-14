module Utils
  def log_cmd logger, cmd
    logger.debug { "Running: #{cmd}" }
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
  end
end
