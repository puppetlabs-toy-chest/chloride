require 'chloride/host'

# Uploads a file to a remote tempdir, copies the file to specified location,
# manages owner/mode on the file, cleans up tempdir.
module Chloride
  class Action::FilePush < Chloride::Action
    # TODO: Document args
    def initialize(args)
      super

      @to_host = args[:to_host] || Chloride::Host.new('localhost', localhost: true)
      @to = args[:to]
      @from = args[:from]
      @content = args[:content]
      @chmod = args[:chmod] || '700'
      @chown = args[:chown] || 'root:root'
      @sudo = args[:sudo] || false
      @opts = (args[:opts] || {}).merge(chunk_size: 16 * 1024)
    end

    # TODO: Document block format
    def go(&stream_block)
      @status = :running

      mktemp = Chloride::Action::Mktemp.new(@to_host, "file-push-XXXXXXXX")
      mktemp.go do |event|
        stream_block.call(event)
      end
      unless mktemp.success?
        @status = :failed
        return
      end

      push = Chloride::Action::FileCopy.new(
        :from    => @from,
        :to      => mktemp.dir,
        :to_host => @to_host,
        :opts    => {:recursive => @opts[:recursive]})
      push.go do |event|
        stream_block.call(event)
      end
      unless push.success?
        @status = :failed
        return
      end

      move = exec_and_log(@to_host, "mv #{mktemp.dir}/* #{@to}", @sudo, {}, &stream_block)
      unless (move[:exit_status]).zero?
        @status = :failed
        return
      end

      set_mode = exec_and_log(@to_host, "chmod -R #{@chmod} #{@to}", @sudo, {}, &stream_block)
      unless set_mode.success?
        @status = :failed
        return
      end

      set_owner = exec_and_log(@to_host, "chown -R #{@chown} #{@to}", @sudo, {}, &stream_block)
      unless set_owner.success?
        @status = :failed
        return
      end

      cleanup = exec_and_log(@to_host, "rm -rf '#{mktemp.dir}'", @sudo, {}, &stream_block)
      unless cleanup.success?
        @status = :failed
        return
      end

      @status = :success
    end

    def success?
      @status == :success
    end

    def name
      :file_push
    end

    def description
      file = @from || 'file content'
      command = @opts[:recursive] ? 'Push recursively' : 'Push'
      "#{command} #{file} to #{@to_host}:#{@to}"
    end
  end
end
