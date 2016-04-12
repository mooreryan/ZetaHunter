require "systemu"
require_relative "../../abort_if/abort_if"

module CoreExtensions
  module Process
    def run_it *a, &b
      exit_status, stdout, stderr = systemu *a, &b

      puts stdout unless stdout.empty?
      $stderr.puts stderr unless stderr.empty?

      exit_status.exitstatus
    end

    def run_it! *a, &b
      exit_status = self.run_it *a, &b

      AbortIf::Abi.abort_unless exit_status.zero?,
                       "ERROR: non-zero exit status (#{exit_status})"

      exit_status
    end
  end
end
