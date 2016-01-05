module Assert
  class AssertionFailureError < Exception
  end

  def self.assert test, msg="", *args
    unless test
      if block_given?
        yield
      end

      raise Assert::AssertionFailureError, msg % args, caller
    end
  end

  def self.assert_file fname
    self.assert File.exists?(fname),
                "File '%s' does not exist.",
                fname
  end

  def self.assert_keys hash, *keys
    self.assert hash.respond_to? :[]

    self.assert keys.all? { |key| hash[key] },
                "Not all keys are present"
  end
end
