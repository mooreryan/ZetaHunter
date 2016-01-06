this_dir = File.dirname(__FILE__)

require File.join this_dir, "assert", "assert.rb"

Dir[File.join(this_dir, "core_extensions", "*", "*.rb")].each do |file|
  require file
end
