require 'chloride/step'

class Chloride::Step::Noop < Chloride::Step
  def initialize(data={}, pre=nil, post=nil)
    super(data, pre, post)
    @name = data[:name]
    @performed = false
  end

  def perform_step(&stream_block)
    @performed = true
    # noop
  end

  def performed?
    @performed
  end

  def name
    @name
  end

  def description
    "Do basically nothing"
  end
end
