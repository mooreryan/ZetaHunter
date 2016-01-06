require "systemu"

module CoreExtensions
  module Process
    def run_it *a, &b
      exit_status, stdout, stderr = systemu *a, &b

      puts stdout.chomp
      $stderr.puts stderr.chomp

      exit_status.exitstatus
    end

    def run_it! *a, &b
      exit_status = self.run_it *a, &b

      unless exit_status.zero?
        abort "ERROR: non-zero exit status (#{exit_status}) " +
              "from #{caller}"
      end
    end
  end
end
