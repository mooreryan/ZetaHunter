this_dir = File.dirname(__FILE__)

require_relative File.join "assert", "assert.rb"
require_relative File.join "const", "const.rb"

Dir[File.join(this_dir, "core_extensions", "*", "*.rb")].each do |file|
  require file
end

require "fileutils"
require "logger"
require "set"
require "parse_fasta"
