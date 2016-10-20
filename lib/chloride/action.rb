module Chloride
  class Action
      def initialize(args)
        @data = {}
        @status = :initialized
      end

      def go(&update_block)
        raise NotImplementedError, "Action must implement a go method"
      end

      def update_proc(&stream_block)
        Proc.new do |info, stream, data|
          if stream == :stdout
            severity = :info
          elsif stream == :stderr
            severity = :warn
          else
            raise NotImplementedError, "Unknown stream #{stream}: #{data}"
          end

          progress_event = Chloride::Event.new(:action_progress, self.name)
          message = Chloride::Event::Message.new(severity, info['hostname'], data)
          progress_event.add_message(message)
          stream_block.call(progress_event)
        end
      end

      def exec_and_log(host, cmd, sudo, results, &stream_block)
        event(host, cmd, &stream_block)
        result = host.execute(cmd, sudo, &self.update_proc(&stream_block))

        results[:stdout] = "" if results[:stdout].nil?
        results[:stdout] += result[:stdout] || ""
        results[:stderr] = "" if results[:stderr].nil?
        results[:stderr] += result[:stderr] || ""
        results[:exit_status] = result[:exit_status]

        result
      end

      def event(host, message, &stream_block)
        event = Chloride::Event.new(:action_progress, self.name)
        if host.localhost
          msg = Chloride::Event::Message.new(:info, host, "[localhost/#{host}] #{message}\n\n")
        else
          msg = Chloride::Event::Message.new(:info, host, "[#{host}] #{message}\n\n")
        end
        event.add_message(msg)
        stream_block.call(event)
      end

      def success?
        false
      end

      def name
        raise NotImplementedError, "Action must have a name"
      end

      def description
        raise NotImplementedError, "Action must have a description"
      end
  end
end
