class Chloride::RemoteError < RuntimeError; end

# TODO: Namespace this properly.
class Error < RuntimeError
  attr_reader :error_message

  def initialize(error)
    super(error.to_s)
  end
end
