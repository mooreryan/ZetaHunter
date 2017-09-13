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

module CoreExtensions
  module Time
    def date_and_time fmt="%F %T.%L"
      Object::Time.now.strftime fmt
    end

    def time_it title="", logger=nil, run: true
      if run
        t = Object::Time.now

        yield

        time = Object::Time.now - t

        if title == ""
          msg = "Finished in #{time} seconds"
        else
          msg = "#{title} finished in #{time} seconds"
        end

        if logger
          logger.info msg
        else
          $stderr.puts msg
        end
      end
    end
  end
end
