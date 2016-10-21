require 'chloride/step'

class Chloride::Step::Noop < Chloride::Step
  def initialize(data = {}, pre = nil, post = nil)
    super(data, pre, post)
    @name = data[:name]
    @performed = false
  end

  def perform_step(_execute_block)
    @performed = true
    # noop
  end

  def performed?
    @performed
  end

  attr_reader :name

  def description
    'Do basically nothing'
  end
end
