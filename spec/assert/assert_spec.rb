require "spec_helper.rb"

p Assert::AssertionFailureError

describe Assert::AssertionFailureError do
  it "is a kind of Exception" do
    err = Assert::AssertionFailureError.new
    expect(err).to be_an Exception
  end
end

describe Assert do
  let(:fake_file) do
    File.join File.dirname(__FILE__), "asdfklasdfj.txt"
  end

  let(:klass) { Class.new { extend Assert } }

  let(:passing_test) { 1 == 1 }

  let(:real_file) do
    File.join File.dirname(__FILE__), "assert_spec.rb"
  end

  describe "#assert" do
    it "passes if test is true" do
      expect(klass.assert passing_test).to eq :pass
    end

    it "passes if test is truthy" do
      test = :apple
      expect(klass.assert test).to eq :pass
    end

    context "when test fails and no msg is specified" do
      it "raises Assert::AssertionFailureError with empty message" do
        test = 1 == 2
        expect { klass.assert test }.
          to raise_error(Assert::AssertionFailureError, "")
      end
    end

    context "when test fails and a msg is specified" do
      it "raises Assert::AssertionFailureError with the message" do
        test = 1 == 2
        msg = "I failed"
        expect { klass.assert test, msg }.
          to raise_error(Assert::AssertionFailureError, msg)
      end

      it "can accept args to be interpolated into msg" do
        test = 1 == 2
        msg = "%d doesn't equal %d"
        expect { klass.assert test, msg, 1, 2 }.
          to raise_error(Assert::AssertionFailureError,
                         "1 doesn't equal 2")
      end
    end

    context "when test fails and a block is given" do
      it "yields the block before raising error"
    end
  end

  describe "#assert_file" do
    context "when file exists" do
      it "passes" do
        expect(klass.assert_file real_file).to eq :pass
      end
    end

    context "when file does not exist" do
      it "raises Assert::AssertionFailureError" do
        msg = "File '#{fake_file}' does not exist."
        expect { klass.assert_file fake_file }.
          to raise_error Assert::AssertionFailureError, msg
      end
    end
  end

  describe "#assert_includes" do
    context "when coll doesn't respond to :include?" do
      it "raises Assert::AssertionFailureError" do
        msg = "Collection does not respond to :include?"

        expect { klass.assert_includes 5, 8 }.
          to raise_error Assert::AssertionFailureError, msg
      end
    end

    context "when coll includes obj" do
      it "passes" do
        expect(klass.assert_includes [1,2,3], 2).to eq :pass
      end
    end

    context "when coll does not include obj" do
      it "raises Assert::AssertionFailureError" do
        msg = "Expected [1, 2, 3] to include 5"
        expect{klass.assert_includes [1,2,3], 5}.
          to raise_error Assert::AssertionFailureError, msg
      end
    end
  end
end
