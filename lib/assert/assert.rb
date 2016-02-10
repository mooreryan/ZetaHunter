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
