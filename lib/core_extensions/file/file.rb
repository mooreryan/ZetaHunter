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
  end
end
