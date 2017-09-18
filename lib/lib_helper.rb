# Copyright 2016 - 2017 Ryan Moore
# Contact: moorer@udel.edu
#
# This file is part of ZetaHunter.
#
# ZetaHunter is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ZetaHunter is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ZetaHunter.  If not, see <http://www.gnu.org/licenses/>.

this_dir = File.dirname(__FILE__)

require_relative File.join "abort_if", "abort_if.rb"
require_relative File.join "assert", "assert.rb"
require_relative File.join "const", "const.rb"
require_relative File.join "utils", "utils.rb"
require_relative "version"

Dir[File.join(this_dir, "core_extensions", "*", "*.rb")].each do |file|
  require file
end

require "fileutils"
require "log4r"
require "set"
require "parse_fasta"
require "abort_if"

require "tmpdir"
