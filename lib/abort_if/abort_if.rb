# Monkey patch of AbortIf module
module AbortIf
  class Abi
    extend AbortIf
  end

  def set_logger logger
    @@logger = logger
  end
end
