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

module Assert
  class AssertionFailureError < Exception
  end

  def assert test, msg="", *args
    unless test
      if block_given?
        yield
      end

      raise Assert::AssertionFailureError, msg % args, caller
    end

    :pass
  end

  def assert_file fname
    self.assert File.exists?(fname),
                "Expected file '%s' to exist.",
                fname
  end

  def assert_includes coll, obj
    assert coll.respond_to?(:include?),
           "Collection does not respond to :include?"

    assert coll.include?(obj),
           "Expected coll to include %s",
           obj.inspect
  end

  def assert_keys hash, *keys
    assert hash.respond_to?(:[]),
           "Collection does not respond to :[]"

    assert keys.count > 0,
           "Keys argument is empty"

    assert keys.all? { |key| hash[key] },
           "Not all keys are present"
  end

  def assert_seq_len seq, name="Sequence"
    assert seq.length == Const::SILVA_ALN_LEN,
           "%s length is %d, but should be %d",
           name,
           seq.length,
           Const::SILVA_ALN_LEN
  end

  def refute test, msg="", *args
    assert !test, msg, *args
  end

  def refute_includes coll, obj
    assert coll.respond_to?(:include?),
           "Collection does not respond to :include?"

    refute coll.include?(obj),
           "Expected coll not to include %s",
           obj.inspect
  end

  def refute_has_key hash, key
    assert hash.respond_to?(:has_key?), "First arg was not a hash"

    refute hash.has_key?(key),
           "Expected hash not to have key %s",
           key.inspect
  end
end
