require 'chloride/errors'

# Creates a directory on the hosts provided. Will block until completion.
module Chloride
  class Action::Mkdir < Chloride::Action
    attr_reader :results, :hosts

    # TODO: Document args
    def initialize(host, dir, args = {})
      super(args)

      @host = host
      @dir = dir
      @chmod = args[:chmod] || '700'
      @sudo = args[:sudo] || false
    end


    # TODO: Document block format
    def go(&stream_block)
      @status = :running
      @results = { @host.hostname => {} }
      mkdir = exec_and_log(@host, "mkdir -p '#{@dir}' -m #{@chmod}", @sudo, @results[@host.hostname], &stream_block)

      if mkdir[:exit_status] == 0
        exec_and_log(@host, "chmod #{@chmod} #{@dir}", @sudo, @results[@host.hostname], &stream_block)
      end

      @results
    end

    def success?
      @results.all? do |_host, result|
        result[:exit_status] == 0
      end
    end

    def error_message(hostname)
      if @results.has_key?(hostname) && @results[hostname].has_key?(:stderr)
        @results[hostname][:stderr].strip
      end
    end

    def name
      :mkdir
    end

    def description
      "Make directory `#{@dir}` on #{@hosts.join(', ')}"
    end
  end
end
