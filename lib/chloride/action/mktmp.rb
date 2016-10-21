require 'chloride/errors'

# Creates a temp directory on the hosts provided. Will block until completion.
module Chloride
  class Action::Mktemp < Chloride::Action
    attr_reader :results, :hosts

    # TODO: Document args
    def initialize(host, template, args = {})
      super(args)

      @host = host
      @template = template
      @chmod = args[:chmod] || '700'
      @sudo = args[:sudo] || false
    end

    # TODO: Document block format
    def go(&stream_block)
      @status = :running
      @results = { @host.hostname => {} }
      mktemp = exec_and_log(@host, "mktemp -d -t '#{@template}'", @sudo, @results[@host.hostname], &stream_block)

      if (mktemp[:exit_status]).zero?
        @dir = mktemp[:stdout].strip
        exec_and_log(@host, "chmod #{@chmod} #{@dir}", @sudo, @results[@host.hostname], &stream_block)
      end

      @results
    end

    def success?
      @results.all? do |_host, result|
        (result[:exit_status]).zero?
      end
    end

    attr_reader :dir

    def error_message(hostname)
      if @results.key?(hostname) && @results[hostname].key?(:stderr)
        @results[hostname][:stderr].strip
      end
    end

    def name
      :mktemp
    end

    def description
      "Make temporary directory on #{@hosts.join(', ')}"
    end
  end
end
