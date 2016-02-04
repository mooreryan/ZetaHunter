require "spec_helper"

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

  let(:hash) { { a: 1, b: 2, c: 3 } }

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
        msg = "Expected file '#{fake_file}' to exist."
        expect { klass.assert_file fake_file }.
          to raise_error Assert::AssertionFailureError, msg
      end
    end
  end

  shared_examples_for "include-type assertions" do |method|
    context "when coll doesn't respond to :include?" do
      it "raises Assert::AssertionFailureError" do
        msg = "Collection does not respond to :include?"
        coll = 10
        obj = 5

        expect { klass.send(method, coll, obj) }.
          to raise_error Assert::AssertionFailureError, msg
      end
    end
  end

  describe "#assert_includes" do
    it_behaves_like "include-type assertions", :assert_includes

    context "when coll includes obj" do
      it "passes" do
        expect(klass.assert_includes [1,2,3], 2).to eq :pass
      end
    end

    context "when coll does not include obj" do
      it "raises Assert::AssertionFailureError" do
        msg = "Expected coll to include 5"
        expect{klass.assert_includes [1,2,3], 5}.
          to raise_error Assert::AssertionFailureError, msg
      end
    end
  end

  describe "#assert_keys" do
    context "when coll doesn't respond to :[]" do
      it "raises Assert::AssertionFailureError" do
        msg = "Collection does not respond to :[]"

        expect { klass.assert_keys false, :a }.
          to raise_error Assert::AssertionFailureError, msg
      end
    end

    context "when keys argument is empty" do
      it "raises Assert::AssertionFailureError" do
        msg = "Keys argument is empty"

        expect { klass.assert_keys hash }.
          to raise_error Assert::AssertionFailureError, msg
      end
    end

    context "when all keys have non-nil values" do
      it "passes" do
        expect(klass.assert_keys hash, :a, :b).to eq :pass
      end
    end

    context "when at least one key has nil value" do
      it "raises Assert::AssertionFailureError" do
        msg = "Not all keys are present"

        expect { klass.assert_keys hash, :a, :z }.
          to raise_error Assert::AssertionFailureError, msg
      end
    end
  end

  describe "#refute" do
    it "passes when test is false" do
      expect(klass.refute [1,2,3].include? 5).to eq :pass
    end

    it "raises Assert::AssertionFailureError when test is true" do
      expect { klass.refute [1,2,3].include? 3 }.
        to raise_error Assert::AssertionFailureError
    end
  end

  describe "#refute_includes" do
    it_behaves_like "include-type assertions", :refute_includes

    context "when coll includes obj" do
      it "passes" do
        expect(klass.refute_includes [1,2,3], 5).to eq :pass
      end
    end

    context "when coll does not include obj" do
      it "raises Assert::AssertionFailureError" do
        msg = "Expected coll not to include 3"

        expect{klass.refute_includes [1,2,3], 3}.
          to raise_error Assert::AssertionFailureError, msg
      end
    end
  end

  describe "#refute_has_key" do
    context "when first arg isn't a hash" do
      it "raises Assert::AssertionFailureError" do
        msg = "First arg was not a hash"

        expect { klass.refute_has_key [1,2,3], :a }.
          to raise_error Assert::AssertionFailureError, msg
      end
    end

    context "when key is present" do
      it "raises Assert::AssertionFailureError" do
        key = :a
        msg = "Expected hash not to have key #{key.inspect}"

        expect { klass.refute_has_key({a: 3}, key) }.
          to raise_error Assert::AssertionFailureError, msg
      end
    end

    context "when key is not present in hash" do
      it "passes" do
        expect(klass.refute_has_key({a: 3}, :b)).to eq :pass
      end
    end
  end
end
