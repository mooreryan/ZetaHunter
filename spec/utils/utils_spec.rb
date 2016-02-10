require "spec_helper"
require "logger"

describe Utils do
  let(:klass) { Class.new { extend Utils } }
  let(:logger) { Logger.new STDERR }

  describe "#log_cmd" do
    it "prints command to Logger level debug"
  end

  describe "#gap?" do
    context "the character is an A C T G U or N (case insensitive)" do
      it "returns nil" do
        %w[a c t g u n A C T G U N].each do |char|
          expect(klass.gap? char).to be nil
        end
      end
    end

    context "the character is anything else" do
      it "returns MatchData" do
        gap_chars =
          (0..255).map { |n| n.chr } - %w[a c t g n u A C T G N U]

        gap_chars.each do |n|
          expect(klass.gap? n.chr).to be_a MatchData
        end
      end
    end
  end
end
