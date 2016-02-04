require "spec_helper"

describe CoreExtensions::Hash do
  Hash.include CoreExtensions::Hash
  let(:hash) { Hash.new }

  describe "#store_in_array" do
    context "when key is not present in hash" do
      it "stores [value] at key" do
        hash.store_in_array :a, 10

        expect(hash[:a]).to eq [10]
      end
    end

    context "when key is present in hash" do
      it "pushes value onto the array already present" do
        hash.store_in_array :a, 10
        hash.store_in_array :a, 20

        expect(hash[:a]).to eq [10, 20]
      end
    end

    context "when value at key is not an array" do
      it "raises Assert::AssertionFailureError" do
        val = 10
        msg = "undefined method `push' for #{val}:#{val.class}"
        hash[:a] = 234
        expect { hash.store_in_array :a, val }.
          to raise_error Assert::AssertionFailureError, msg
      end
    end
  end
end
