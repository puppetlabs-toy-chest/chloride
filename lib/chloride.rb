require 'chloride/version'
require 'chloride/action/execute'
require 'chloride/action/file_copy'
require 'chloride/action/mkdir'
require 'chloride/action/mktmp'
require 'chloride/action/resolve_dns'
require 'chloride/host'
require 'chloride/ssh_known_hosts'

module Chloride
  def self.go_execute(hostname, command)
    host = Chloride::Host.new(hostname)
    host.ssh_connect

    remote_command = Chloride::Action::Execute.new(
      host: host,
      sudo: true,
      cmd: command
    )

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

  def self.go_action(hostname, action, opts)
    host = Chloride::Host.new(hostname)
    host.ssh_connect

    action_class = case action
    when 'file_copy'
      opts[:to_host] = host
      Chloride::Action::FileCopy
    else
      raise "Unknown or unsupported action #{action_class}"
    end

    remote_action = action_class.new(opts)

    remote_action.go do |event|
      event.data[:messages].each do |data|
        puts "[#{data.severity}:#{data.hostname}]: #{data.message}"
      end
    end

    if remote_action.success?
      puts "We were successful at running '#{action}' on #{hostname}"
    else
      puts "We failed to run '#{action}' with error code #{remote_action.status} on #{hostname}"
    end
  end
end
