class Chloride::Executor
  def initialize(logger, &stream_block)
    @logger = logger
    @stream_block = stream_block
  end

  def publish(event, action_id = nil)
    event.action_id = action_id if action_id
    @stream_block.call(event) if @stream_block
  end

  def execute(steps)
    # Perform the plan given
    skip_remaining_steps = false

    steps.each do |step|
      # TODO: Check for step.pre
      if skip_remaining_steps
        publish Chloride::Event.new(:step_skip, step.name)
        next
      end

      publish Chloride::Event.new(:step_start, step.name)

      begin
        step.perform_step do |action|
          action_id = SecureRandom.uuid
          publish(Chloride::Event.new(:action_start, action.name), action_id)

          action.go do |event|
            publish(event, action_id)
          end

          if action.success?
            publish(Chloride::Event.new(:action_success, action.name), action_id)
          else
            publish(Chloride::Event.new(:action_fail, action.name), action_id)
          end
        end
      rescue Exception => e # rubocop:disable Lint/RescueException
        # Treat *any* error like a step failure and proceed accordingly
        @logger.error [e, *e.backtrace].join("\n")
        step.error(step.infra.installer_hostname, "An error occured while performing #{step.name}: #{e.message}")
      end

      type = case step.status
             when :error
               skip_remaining_steps = step.fail_stop?
               :step_error
             when :warn
               :step_warn
             else
               :step_success
             end

      Chloride::Event.new(type, step.name).tap do |event|
        step.messages.each { |m| event.add_message(m) }
        publish event
      end

      # Clear the messages so that revalidation doesn't log them again
      step.reset

      # TODO: Check for step.post
    end
  end
end
