require "abort_if"

module CoreExtensions
  module Dir
    def try_mkdir dir
      begin
        Object::Dir.mkdir dir
      rescue SystemCallError => e
        AbortIf::Abi.abort_if true,
                 "Could not make dir #{dir}, #{e.message}"
      end
    end
  end
end
