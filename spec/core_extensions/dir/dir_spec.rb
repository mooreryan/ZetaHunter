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

require "spec_helper"
require "fileutils"

describe CoreExtensions::Dir do
  Dir.extend CoreExtensions::Dir

  let(:test_f_dir) do
    File.absolute_path(File.join(File.dirname(__FILE__),
                                 "..", "..",
                                 "test_files"))
  end


  describe "::try_mkdir" do
    it "makes directory if possible" do
      dir = File.join test_f_dir, "apple_pie_is_nice"

      Dir.try_mkdir dir

      expect(File.exists? dir).to be true

      FileUtils.rmdir dir
    end

    it "raise AbortIf::Exit if SystemCallError is raised" do
      dir = "/apple_pie_is_nice/and_funny"

      expect { Dir.try_mkdir dir }.to raise_error AbortIf::Exit
    end
  end
end
