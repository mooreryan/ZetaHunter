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

require 'spec_helper'

# This needs to be a relative path to test the path expansion of the
# program.  The path is relative to the location you run the rspec
# command.
RUN_ZH_TEST_DIR = File.join "spec", "test_files", "run_zeta_hunter"

RUN_ZETA_HUNTER = File.join Const::PROJ_DIR, "bin", "run_zeta_hunter"

RUN_ZH_OUTDIR = File.join Const::PROJ_DIR, "spec", "test_files", "run_zeta_hunter", "snazzy_test", "TEST_OUTPUT"

klass = Class.new { extend CoreExtensions::Process }

describe ZetaHunter do
  it 'has a version number' do
    expect(ZetaHunter::VERSION).not_to be nil
  end

  shared_examples_for "test_the_options" do |outdir_addition, cmd_addition|
    it "changing #{outdir_addition} option works" do
      this_outdir = outdir + "_#{outdir_addition}"
      final_otu_calls = File.join(this_outdir, "otu_calls", "#{base}.otu_calls.final.txt")

      if Dir.exist? this_outdir
        FileUtils.rm_r this_outdir
      end

      this_command = "#{RUN_ZETA_HUNTER} " \
                     "--base #{base} " \
                     "--inaln #{inaln} " \
                     "--outdir #{this_outdir} " + cmd_addition

      expect { klass.run_it!(this_command) }.not_to raise_error
      expect(File.read(File.absolute_path final_otu_calls)).to eq expected

      if Dir.exist? this_outdir
        begin
          FileUtils.rm_r this_outdir
        rescue Errno::EACCES => e
          STDERR.puts "Error: Could not erase '#{this_outdir}'.  Just going to leave it."
        end
      end
    end
  end

  # Testing the run_zeta_hunter Docker script.
  describe "run_zeta_hunter", speed: "slow" do
    let(:snazzy_dir) { File.join RUN_ZH_TEST_DIR, "snazzy_test" }
    let(:outdir) { File.join snazzy_dir, "TEST_OUTPUT" }
    let(:inaln) { [File.join(snazzy_dir, "'dir with spaces'", "*"),
                   File.join(snazzy_dir, "dir_without_spaces", "*")].join(" ") }
    let(:base) { "BASE" }
    # let(:final_otu_calls) { Dir.glob(File.join(RUN_ZH_OUTDIR, "otu_calls", "*.otu_calls.final.txt")).first }

    let(:expected) { File.read(File.join(RUN_ZH_TEST_DIR, "snazzy_test_final_otu_calls.txt")) }

    before :each do
      if Dir.exist? RUN_ZH_OUTDIR
        FileUtils.rm_r RUN_ZH_OUTDIR
      end
    end

    after :each do
      if Dir.exist? RUN_ZH_OUTDIR
        FileUtils.rm_r RUN_ZH_OUTDIR
      end
    end

    include_examples "test_the_options", "mostly_defualt", ""
    include_examples "test_the_options", "threads", "--threads 3"
    include_examples "test_the_options", "otu_percent", "--otu-percent 97"
    include_examples "test_the_options", "check_chimeras", "--check-chimeras"


    # it "works mostly defualt options" do
    #   this_outdir = outdir + "_mostly_defualt"
    #   final_otu_calls = File.join(this_outdir, "otu_calls", "#{base}.otu_calls.final.txt")

    #   if Dir.exist? this_outdir
    #     FileUtils.rm_r this_outdir
    #   end

    #   cmd = "#{RUN_ZETA_HUNTER} " \
    #         "--base #{base} " \
    #         "--inaln #{inaln} " \
    #         "--outdir #{this_outdir} "

    #   expect { klass.run_it! cmd }.not_to raise_error
    #   expect(File.read(File.absolute_path final_otu_calls)).to eq expected

    #   if Dir.exist? this_outdir
    #     FileUtils.rm_r this_outdir
    #   end
    # end


  end
end
