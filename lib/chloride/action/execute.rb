require 'chloride/errors'
require 'chloride/event'
require 'chloride/action'

# Executes a shell command on the hosts provided. Will block until completion.
module Chloride
  class Action::Execute < Chloride::Action
    attr_reader :results, :hosts

    # TODO: Document args
    def initialize(args)
      super

      @hosts = args[:hosts] || [args[:host]]
      @cmd = args[:cmd]
      @sudo = args[:sudo] || false
    end


    # TODO: Document block format
    def go(&stream_block)
      @status = :running
      @results = {}
      @hosts.each do |host|
        cmd_event = Chloride::Event.new(:action_progress, self.name)
        if host.localhost
          msg = Chloride::Event::Message.new(:info, host, "[localhost/#{host}] #{@cmd}\n\n")
        else
          msg = Chloride::Event::Message.new(:info, host, "[#{host}] #{@cmd}\n\n")
        end
        cmd_event.add_message(msg)
        stream_block.call(cmd_event)
        @results[host.hostname] = host.execute(@cmd, @sudo, &self.update_proc(&stream_block))
      end

      @results
    end

    def success?
      @results.all? do |host, result|
        result[:exit_status] == 0
      end
    end

    def error_message(hostname)
      if @results.has_key?(hostname) && @results[hostname].has_key?(:stderr)
        @results[hostname][:stderr].strip
      end
    end

    def name
      :execute
    end

    def description
      "Execute `#{@cmd}` on #{@hosts.join(', ')}"
    end
  end
end
