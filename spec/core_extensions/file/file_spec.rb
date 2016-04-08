require "spec_helper"
require "fileutils"

describe CoreExtensions::File do
  File.extend CoreExtensions::File
  let(:klass) { Class.new { extend CoreExtensions::File } }
  let(:filename) { CoreExtensions::File::Filename.new dir, base, ext }

  let(:fname) { File.join "home", "moorer", "apples.txt.gz" }
  let(:dir) { File.join "home", "moorer" }
  let(:base) { "apples.txt" }
  let(:ext) { ".gz" }

  let(:test_f_dir) do
    File.absolute_path(File.join(File.dirname(__FILE__),
                                 "..", "..",
                                 "test_files"))
  end

  let(:bad_fname) do
    File.absolute_path(File.join(test_f_dir,
                                 "bad-dir-name",
                                 "bad--fnam es.txt"))
  end

  let(:clean_fname) do
    File.join test_f_dir, "bad_dir_name", "bad_fnam_es.txt"
  end

  let(:entropy) { [0.5, 1.3, 1.0, 1.1] }
  let(:entropy_f) { File.join test_f_dir, "entropy.test.txt" }

  let(:names) { Set.new %w[Ryan Dan] }
  let(:names_f) { File.join test_f_dir, "names.test.txt" }


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

  describe "#clean_fname" do
    it "cleans the file name" do
      str = "/Users/moorer/ap38*02.9-_;>46.txt"
      expect(File.clean_fname str).to eq "/Users/moorer/ap38_02.9_46.txt"
    end
  end

  describe "clean_and_copy" do
    it "cleans the file name" do
      expect(File.clean_and_copy bad_fname).
        to eq clean_fname
    end

    it "makes a copy of the file in new clean file name" do
      # remove clean_fname in case it is still present
      FileUtils.rm clean_fname

      File.clean_and_copy bad_fname

      old_contents = File.read bad_fname
      new_contents = File.read clean_fname

      expect(new_contents).to eq old_contents
    end
  end

  describe "read_entropy" do
    context "with good input" do
      it "returns an array with entropy values" do
        expect(klass.read_entropy entropy_f).to eq entropy
      end
    end

    context "with bad input" do
      it "raises AbortIf::Exit"
    end
  end

  describe "to_set" do
    it "reads contents of file to set" do
      expect(klass.to_set names_f).to eq names
    end
  end
end
