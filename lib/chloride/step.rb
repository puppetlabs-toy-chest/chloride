class Chloride::Step
  attr_reader :actions, :hosts, :messages, :status

  def initialize(data = {}, pre = nil, post = nil)
    @pre = pre
    @post = post
    @data = data
    @hosts = Set.new

    @actions = []
    @messages = []

    @status = :success
    @uuid = SecureRandom.uuid
  end

  def perform_step(_execute_block)
    raise NotImplementedError, "Don't know how to perform this kind of step"
  end

  def name
    raise NotImplementedError, 'Step name required'
  end

  def description
    raise NotImplementedError, 'Step description required'
  end

  def fail_stop?
    false
  end

  def reset
    @status = :success
    @messages.clear
  end

  def error(hostname, message)
    @messages << Chloride::Event::Message.new(:error, hostname, message)
    @status = :error
  end

  def warning(hostname, message)
    @messages << Chloride::Event::Message.new(:warn, hostname, message)
    @status = :warn unless @status == :error
  end

  def info(hostname, message)
    @messages << Chloride::Event::Message.new(:info, hostname, message)
  end
end

require 'chloride/event'
