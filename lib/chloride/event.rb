require 'json'
require 'chloride/event/message'
class Chloride::Event
  attr_reader :type, :name, :time, :call_stack, :data
  attr_accessor :action_id

  def initialize(type, name, data={})
    @time = Time.now.utc
    @type = type
    @name = name
    @data = data.merge(messages: [])
    @call_stack = caller
  end

  def messages
    @data[:messages]
  end

  def add_message(message)
    @data[:messages] << message
  end

  def to_publish_s
    metadata = {
      time: @time.to_i,
      name: @name,
      action_id: @action_id,
    }

    json = @data.merge(metadata).to_json

    # The two newlines at the end mark the message 'complete' and renderable
    "event: #{@type}\ndata: #{json}\n\n"
  end

  def log(logger)
    @data[:messages].each do |msg|
      logger.send(msg.severity, msg.message.strip)
    end
  end
end
