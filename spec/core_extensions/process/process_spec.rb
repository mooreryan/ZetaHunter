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

describe CoreExtensions::Process do
  Process.extend CoreExtensions::Process

  shared_examples "for running commands" do
    it "returns the exit status" do
      cmd = "echo 'hi'"

      expect(Process.send(method, cmd)).to eq 0
    end

    it "outputs stdout of cmd to stdout" do
      cmd = "echo 'hi'"

      expect { Process.send(method, cmd) }.to output("hi\n").to_stdout
    end

    it "outputs stderr of cmd to stderr" do
      cmd = ">&2 echo 'hi'"

      expect { Process.send(method, cmd) }.to output("hi\n").to_stderr
    end
  end

  describe "#run_it" do
    include_examples "for running commands" do
      let(:method) { :run_it }
    end

    it "doesn't raise SystemExit if cmd has nonzero exit status" do
      expect { Process.run_it "ls woiruoweiruw" }.
        not_to raise_error
    end
  end

  describe "#run_it!" do
    include_examples "for running commands" do
      let(:method) { :run_it! }
    end

    it "raises SystemExit if cmd has nonzero exit status" do
      expect { Process.run_it! "ls woiruoweiruw" }.
        to raise_error SystemExit
    end
  end
end
