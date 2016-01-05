module CoreExtensions
  module Time
    def date_and_time fmt="%F %T.%L"
      Object::Time.now.strftime fmt
    end

    def time_it title
      t = Object::Time.now
      yield

      return "#{title} finished in #{Object::Time.now - t} seconds"
    end
  end
end

# require "logger"

# Time.extend CoreExtensions::Time

# logger = Logger.new(STDERR)

# logger.info Time.time_it("A Not in block") { puts :a }
# logger.info { Time.time_it("B In block") { puts :b } }

# logger.level = Logger::ERROR

# logger.info Time.time_it("C Not in block") { puts :c }
# logger.info { Time.time_it("D In block") { puts :d } }
