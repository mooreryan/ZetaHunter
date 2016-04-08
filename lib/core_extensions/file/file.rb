module CoreExtensions
  module File
    Filename = Struct.new :dir, :base, :ext

    def parse_fname fname
      Filename.new Object::File.dirname(fname),
                   Object::File.basename(fname,
                                         Object::File.extname(fname)),
                   Object::File.extname(fname)
    end

    def clean_fname str
      str.split(Object::File::SEPARATOR).
        map { |s| s.gsub(/[^\p{Alnum}\.]+/, "_") }.
        join(Object::File::SEPARATOR)
    end

    def clean_and_copy fname
      new_fname = clean_fname fname
      new_dirname = Object::File.dirname new_fname

      unless new_fname == fname

        FileUtils.mkdir_p new_dirname
        FileUtils.cp fname, new_fname

        # logger.info { "Copying #{fname} to #{new_fname}" }

        # assert_file new_fname
      end

      new_fname
    end

    def read_entropy fname
      entropy = []
      Object::File.open(fname).each_line do |line|
        idx, ent = line.chomp.split "\t"
        # assert !idx.nil? && !idx.empty?
        # assert !ent.nil? && !ent.empty?

        entropy[idx.to_i] = ent.to_f
      end

      # assert entropy.count == MASK_LEN,
      #        "Entropy count was %d should be %d",
      #        entropy.count,
      #        MASK_LEN

      entropy
    end

    def to_set fname
      lines = []
      Object::File.open(fname).each_line do |line|
        lines << line.chomp
      end

      Set.new lines
    end
  end
end
