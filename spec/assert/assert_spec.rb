# Copyright 2016 - 2017 Ryan Moore
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

  let(:seq) { "A" * (Const::SILVA_ALN_LEN - 1) }

  describe "#assert_seq_len" do
    context "when sequence length is SILVA_ALN_LEN" do
      it "passes" do
        seq = "A" * Const::SILVA_ALN_LEN
        expect(klass.assert_seq_len seq).to eq :pass
      end
    end

    context "when sequence length is not SILVA_ALN_LEN" do
      it "raises Assert::AssertionFailureError (with default msg)" do
        msg = "Sequence length is #{Const::SILVA_ALN_LEN - 1}, " +
              "but should be #{Const::SILVA_ALN_LEN}"

        expect { klass.assert_seq_len seq }.
          to raise_error Assert::AssertionFailureError, msg
      end

      it "raises Assert::AssertionFailureError (with custom msg)" do
        name = "Apple phage"
        msg = "#{name} length is #{Const::SILVA_ALN_LEN - 1}, " +
              "but should be #{Const::SILVA_ALN_LEN}"

        expect { klass.assert_seq_len seq, name }.
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
