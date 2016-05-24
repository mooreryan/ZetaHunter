# Monkey patch of AbortIf module
require "abort_if"

module AbortIf
  class Abi
    extend AbortIf
    extend Assert
  end

  def abort_if test, msg="Fatal error"
    if test
      logger.fatal "#{msg} -- Stack Trace: #{caller(0).join(" | ")}"
      raise Exit, msg
    end
  end

  def abort_unless_file_exists fname
    abort_unless File.exists?(fname), "File '#{fname}' does not exist"
  end

  def abort_unless_has_keys hash, *keys
    assert hash.respond_to?(:[]),
           "Collection does not respond to :[]"

    assert keys.count > 0,
           "Keys argument is empty"

    abort_unless keys.all? { |key| hash[key] },
                 "Not all keys are present"
  end

  def set_logger logger
    @@logger = logger
  end
end
