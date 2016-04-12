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
