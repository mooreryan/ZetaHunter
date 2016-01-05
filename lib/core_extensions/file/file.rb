module CoreExtensions
  module File
    Filename = Struct.new :dir, :base, :ext

    def parse_fname fname
      Filename.new Object::File.dirname(fname),
                   Object::File.basename(fname,
                                         Object::File.extname(fname)),
                   Object::File.extname(fname)
    end
  end
end
