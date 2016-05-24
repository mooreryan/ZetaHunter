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
      # assumes that rspec is not run in sudo. I'm looking at you
      # Docker....
      dir = "/apple_pie_is_nice"

      expect { Dir.try_mkdir dir }.to raise_error AbortIf::Exit
    end
  end
end
