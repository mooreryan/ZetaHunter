module CoreExtensions
  module Hash
    include Assert

    def store_in_array key, val
      if self.has_key? key
        assert self[key].respond_to?(:push),
               "undefined method `push' for #{val}:#{val.class}"

        self[key].push val
      else
        self[key] = [val]
      end
    end
  end
end
