require 'cgi'

module Chloride
  class Event
    class Message
      attr_reader :severity, :hostname, :message

      def initialize(severity, hostname, message)
        @severity = severity
        @hostname = hostname
        @message = message.encode('utf-8', undef: :replace, invalid: :replace)
      end

      def to_json(*args)
        {
          severity: @severity,
          hostname: @hostname,
          message: CGI.escape_html(remove_ansi(@message))
        }.to_json(*args)
      end

      def remove_ansi(string)
        string.gsub(/\e\[\d{0,2};?\d{0,2}m/, '')
      end
    end
  end
end
