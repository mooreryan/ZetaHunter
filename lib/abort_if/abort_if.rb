# Copyright 2016 - 2018 Ryan Moore
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

# Monkey patch of AbortIf module
require "abort_if"

module AbortIf
  class Abi
    extend AbortIf
    extend Assert
  end

  def abort_if test, msg="Fatal error"
    if test
      logger.fatal "#{msg} -- Stack Trace: #{caller(0).join(" | ")}"
      raise Exit, msg
    end
  end

  def abort_unless_file_exists fname
    abort_unless File.exists?(fname), "File '#{fname}' does not exist"
  end

  def abort_unless_has_keys hash, *keys
    assert hash.respond_to?(:[]),
           "Collection does not respond to :[]"

    assert keys.count > 0,
           "Keys argument is empty"

    abort_unless keys.all? { |key| hash[key] },
                 "Not all keys are present"
  end

  def set_logger logger
    @@logger = logger
  end
end
