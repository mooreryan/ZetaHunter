module CoreExtensions
  module Time
    def date_and_time fmt="%F %T.%L"
      Object::Time.now.strftime fmt
    end

    def time_it title="", logger=nil, run: true
      if run
        t = Object::Time.now

        yield

        time = Object::Time.now - t

        if title == ""
          msg = "Finished in #{time} seconds"
        else
          msg = "#{title} finished in #{time} seconds"
        end

        if logger
          logger.info msg
        else
          $stderr.puts msg
        end
      end
    end
  end
end

# require "logger"

# Time.extend CoreExtensions::Time

# Time.time_it { sleep(2) }

# logger = Logger.new(STDERR)

# logger.info Time.time_it("A Not in block") { puts :a }
# logger.info { Time.time_it("B In block") { puts :b } }

# logger.level = Logger::ERROR

# logger.info Time.time_it("C Not in block") { puts :c }
# logger.info { Time.time_it("D In block") { puts :d } }
