module CoreExtensions
  module Logger
    @@time_it_count = 0

    def time_it title
      @@time_it_count += 1
      t = Time.now
      yield
      $stderr.print "\n\nRan Step #{@@time_it_count} -- #{title} -- " +
                    "in #{Time.now - t} seconds\n\n"
    end
  end
end
