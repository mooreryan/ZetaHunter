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
                "File '%s' does not exist.",
                fname
  end

  def assert_keys hash, *keys
    assert hash.respond_to? :[]

    assert keys.all? { |key| hash[key] },
           "Not all keys are present"
  end

  def refute test, msg="", *args
    assert !test, msg, *args
  end

  def refute_includes coll, obj
    assert coll.respond_to? :include?

    refute coll.include?(obj),
           "Expected %s not to include %s",
           coll.inspect,
           obj.inspect
  end

  def refute_has_key hash, key
    assert hash.respond_to? :has_key?

    refute hash.has_key?(key),
           "%s is already a key in %s",
           key.inspect,
           hash.keys.inspect
  end
end
