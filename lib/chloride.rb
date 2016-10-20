require "chloride/version"
require "chloride/action/execute"
require "chloride/action/file_copy"
require "chloride/action/mkdir"
require "chloride/action/mktmp"
require "chloride/action/resolve_dns"
require "chloride/host"

module Chloride
  def self.go_execute(hostname, command)
    host = Chloride::Host.new(hostname)
    host.ssh_connect

    remote_command = Chloride::Action::Execute.new(
      :host => host,
      :sudo => true,
      :cmd  => command)

    remote_command.go do |event|
      event.data[:messages].each do |data|
        puts "[#{data.severity}:#{data.hostname}]: #{data.message}"
      end
    end

    if remote_command.success?
      puts "We were successful at running '#{command}' on #{hostname}"
    else
      puts "We failed to run '#{command}' with error code #{remote_command.status} on #{hostname}"
    end
  end
end
