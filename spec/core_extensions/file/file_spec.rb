require "spec_helper"

describe CoreExtensions::File do
  File.extend CoreExtensions::File

  let(:filename) { CoreExtensions::File::Filename.new dir, base, ext }

  let(:fname) { File.join "home", "moorer", "apples.txt.gz" }
  let(:dir) { File.join "home", "moorer" }
  let(:base) { "apples.txt" }
  let(:ext) { ".gz" }

  describe CoreExtensions::File::Filename do
    it { should be_a Struct }
    it { should respond_to :dir }
    it { should respond_to :base }
    it { should respond_to :ext }
  end

  describe "#parse_fname" do
    it "parses the file name" do
      expect(File.parse_fname fname).to eq filename
    end

    it "returns a Filename struct" do
      expect(File.parse_fname fname).
        to be_a CoreExtensions::File::Filename
    end
  end
end
