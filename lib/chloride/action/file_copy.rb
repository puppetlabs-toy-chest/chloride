require 'tempfile'
require 'chloride/host'

# Uploads a file to a remote system, or writes to local.
module Chloride
  class Action::FileCopy < Chloride::Action
    # TODO: Document args
    def initialize(args)
      super

      @to_host = args[:to_host] || Chloride::Host.new('localhost', {:localhost => true})
      @to = args[:to]
      @from = args[:from]
      @content = args[:content]
      @opts = (args[:opts] || {}).merge(chunk_size: 16 * 1024)
    end

    # TODO: Document block format
    def go(&stream_block)
      @status = :running

      begin
        if @content
          @from_file = Tempfile.new("chloride-content")
          @from = @from_file.path
          @from_file.write(@content)
          @from_file.flush
          @from_file.close
        end

        cmd_event = Chloride::Event.new(:action_progress, self.name, hostname: @to_host)
        msg = Chloride::Event::Message.new(:info, @to_host, "Copying #{@from} to #{@to_host.hostname}:#{@to}.\n\n")
        cmd_event.add_message(msg)
        stream_block.call(cmd_event)

        file_pcts = Hash.new { |h,k| h[k] = 0 }
        @to_host.upload!(@from, @to, @opts) do |_, file, sent, size|
          pct = (size.zero?) ? 100 : (100.0 * sent / size).to_i
          if [0, 100].include?(pct) || pct > file_pcts[file] + 5
            file_pcts[file] = pct
            evt = Chloride::Event.new(:progress_indicator, self.name, task: "Copying #{file}", percent: pct)
            stream_block.call(evt)
          end
        end

        @status = :success
      rescue Net::SCP::Error => err
        @status = :fail
        msg = Chloride::Event::Message.new(:error, @to_host, "Could not copy '#{@from}' to #{@to_host.hostname}: #{err}")
        cmd_event.add_message(msg)
        stream_block.call(cmd_event)
      end
    end

    def success?
      @status == :success
    end

    def name
      :upload
    end

    def description
      file = @from || 'file content'
      command = @opts[:recursive] ? "Recursively copy" : "Copy"
      "#{command} #{file} to #{@to_host}:#{@to}"
    end
  end
end
