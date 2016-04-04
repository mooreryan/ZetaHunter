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
