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
