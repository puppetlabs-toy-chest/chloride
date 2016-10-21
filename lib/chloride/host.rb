require 'fileutils'
require 'net/ssh'
require 'net/scp'
require 'strscan'
require 'open3'
require 'timeout'
require 'json'

class Chloride::Host
  attr_reader :data, :remote_conn, :roles, :hostname, :username, :ssh_key_file, :ssh_key_passphrase, :alt_names, :localhost
  attr_accessor :data

  def initialize(hostname, config = {})
    @hostname = hostname
    @username = if config[:username].nil? || config[:username].strip.empty?
                  'root'
                else
                  config[:username]
                end
    if config[:ssh_key_file] && !config[:ssh_key_file].strip.empty?
      @ssh_key_file = File.expand_path(config[:ssh_key_file])
    end
    @ssh_key_passphrase = config[:ssh_key_passphrase] unless config[:ssh_key_passphrase].nil? || config[:ssh_key_passphrase].strip.empty?
    @localhost = config[:localhost] || false
    @sudo_password = config[:sudo_password] unless config[:sudo_password].nil? || config[:sudo_password].empty?
    @data = {}
    @timeout = 60
    @ssh_status = nil
  end

  # Initializes SSH connection/session to host. Must be called before {#ssh} or {#scp}.
  #
  # @returns [Net::SSH::Connection] SSH connection to host.
  def ssh_connect
    unless @localhost
      log = StringIO.new
      logger = Logger.new(log)
      logger.formatter = proc { |level, date, _progname, msg|
        "[#{date.utc.strftime('%Y-%m-%d %H:%M:%S.%L %Z')}] #{level} #{msg}\n"
      }

      ssh_opts = {
        timeout: @timeout,
        passphrase: @ssh_key_passphrase,
        password: @sudo_password,
        logger: logger,
        verbose: :warn
      }.reject { |_, v| v.nil? }

      ssh_opts[:keys] = [@ssh_key_file] if @ssh_key_file

      # Use Ruby timeout because Net::SSH timeout appears to fail sometimes
      Timeout.timeout(@timeout) {
        @ssh = Net::SSH.start(@hostname, @username, ssh_opts)
        @ssh_status = :connected
      }
    end
  rescue Net::SSH::AuthenticationFailed => err
    @ssh_status = :error
    log.rewind
    raise("Authentication failed while attempting to SSH to #{@username}@#{@hostname}: \n#{log.read}")
  rescue Net::SSH::HostKeyError => err
    @ssh_status = :error
    raise("Host key error while attempting to SSH to #{@username}@#{@hostname} with key #{@ssh_key_file}: #{err.message}")
  rescue SocketError => err
    @ssh_status = :error
    raise("Socket error while attempting to SSH to #{@username}@#{@hostname}: #{err.message}")
  rescue Errno::ETIMEDOUT, Timeout::Error => err
    @ssh_status = :error
    log.rewind
    if !log.empty?
      raise("Connection timed out while attempting to SSH to #{@username}@#{@hostname}: \n#{log.read}")
    else
      raise("Connection timed out while attempting to SSH to #{@username}@#{@hostname}: #{err.message}")
    end
  end

  # Shut down the SSH connection/session. Will block until all channels have closed. Removes session from host and returns the closed session.
  #
  # @returns [Net::SSH::Connection] Closed SSH connection
  def ssh_disconnect
    if @localhost
      @ssh_status = :localhost
    else
      Timeout.timeout(@timeout) {
        @ssh.close
        @ssh = nil
        @ssh_status = :disconnected
      }
    end
  rescue Errno::ETIMEDOUT, Timeout::Error => err
    @ssh_status = :error
    raise("Connection timed out while attempting to close SSH to #{@username}@#{@hostname}: #{err.message}")
  end

  # Returns the SSH session that connects to this host. {#ssh_connect} *must* be called before this will return a session, otherwise it will raise an exception.
  #
  # @returns [Net::SSH::Connection] SSH connection to host.
  def ssh
    @ssh || raise("SSH called but connection has not been established for #{@hostname}")
  end

  # Returns the status of the SSH connection to this host.
  # nil - The connection has not been attempted.
  # :connected - There is an active connection
  # :disconnected - The connection has been disconnected.
  # :error - An error occured and SSH will not work correctly.
  # :localhost - SSH is unnecessary because the host is localhost
  #
  # @returns Status of connection: nil, :connected, :disconnected, :error, :localhost
  attr_reader :ssh_status

  # If you would like to open an SCP channel and perform up uploads or downloads:
  # host.scp.download!(@from, @from_file.path, @opts, &stream_block)
  # host.scp.upload!(@from_file.path, @to, @opts, &stream_block)
  def scp
    ssh.scp
  end

  def upload!(*args, &blk)
    if @localhost
      FileUtils.cp_r args[0], args[1], preserve: true, verbose: true
    else
      scp.upload!(*args, &blk)
    end
  end

  def execute(cmd, sudo = false, &stream_block)
    results = { exit_status: nil, stdout: '', stderr: '' }
    sudo = false if @username == 'root'

    if sudo
      # Because we're using a pty, and therefore a shell...
      cmd_no_quotes = cmd.delete("'")
      sudo_prompt = "[sudo] Chloride needs to run #{cmd_no_quotes} as root, please enter password: "
      cmd = "sudo -S -p '#{sudo_prompt}' #{cmd}"
    end

    # Information about the exec that will be passed back to the update blocks
    info = {}

    # Send to results and stream block for display
    send = proc do |info, stream, string|
      stream_block.call(info, stream, string)
      results[stream] << string
    end

    # Buffering so output doesn't get split up in strange ways
    buffers = { stdout: StringScanner.new(''), stderr: StringScanner.new('') }
    buffer_proc = proc do |info, stream, data|
      raise NotImplementedError, "Unknown stream #{stream}" unless [:stdout, :stderr].include? stream
      buffers[stream] << data
      while l = buffers[stream].scan_until(/\n/)
        send.call(info, stream, l)
      end
      buffers[stream].string = buffers[stream].rest
    end

    if @localhost
      info['hostname'] = @hostname
      info['localhost'] = true

      raise 'Must be run as root' if sudo && ENV['USER'] != 'root'

      # Bundler/Ruby env vars we don't want hanging around causing problems
      unsets = ['GEM_HOME', 'RACK_ENV', 'BUNDLE_GEMFILE', 'GEM_PATH',
                'RUBYOPT', '_ORIGINAL_GEM_PATH', 'BUNDLE_BIN_PATH']

      Open3.popen3("unset #{unsets.join(' ')}; /bin/sh") do |stdin, stdout, stderr, wait_thr|
        stdin.puts(cmd)
        stdin.close

        results[:pid] = wait_thr.pid

        while wait_thr.status
          info['thread_status'] = wait_thr.status

          begin
            while out = stdout.gets
              buffer_proc.call(info, :stdout, out)
            end
          rescue IO::WaitReadable => _blocking
            buffer_proc.call(info, :stdout, "Waiting on #{cmd}...")
          end

          begin
            while err = stderr.gets
              buffer_proc.call(info, :stderr, err)
            end
          rescue IO::WaitReadable => _blocking
            buffer_proc.call(info, :stderr, "Waiting on #{cmd}...")
          end
        end

        # Process::Status object returned.
        results[:exit_status] = wait_thr.value.exitstatus
        info['thread_status'] = wait_thr.status

        # Get remaining stdout
        while out = stdout.gets
          send.call(info, :stdout, out)
        end

        # Get remaining stderr
        while err = stderr.gets
          send.call(info, :stderr, err)
        end
      end
    else
      channel = ssh.open_channel do |channel|
        info['hostname'] = channel.connection.host

        channel.request_pty do |_, success|
          raise('Could not acquire tty') unless success

          channel.exec cmd do |_, success|
            raise 'could not execute command' unless success

            # "on_data" is called when the process writes something to stdout
            channel.on_data do |_, data|
              # For some reason, sudo prompt comes over stdout when we are using pty
              if sudo && sudo_stdin(channel, info, data, sudo_prompt, &stream_block)
                # Fake stderr
                buffer_proc.call(info, :stderr, data)
              else
                buffer_proc.call(info, :stdout, data)
              end
            end

            # "on_extended_data" is called when the process writes something to stderr
            channel.on_extended_data do |_, stream, data|
              if stream == 1
                stream = :stderr
              else
                raise NotImplementedError, "Unknown stream: #{stream}"
              end

              buffer_proc.call(info, stream, data)
            end

            channel.on_request('exit-status') do |_, data|
              results[:exit_status] = data.read_long
            end
          end
        end
      end
      channel.wait
    end

    results
  end

  def to_s
    @hostname
  end

  private

  def sudo_stdin(ch, info, data, sudo_prompt, &stream_block)
    # Sudo handling
    if data == sudo_prompt
      if @sudo_password
        ch.send_data "#{@sudo_password}\r\n"
      else
        raise Chloride::RemoteError, "Sudo password for user #{@username} was not provided"
      end

      ch.wait

      true
    elsif data =~ /^#{@username} is not in the sudoers file./
      # Sudo failed, wrong user. Bail out.
      stream_block.call(info, :stderr, "Cannot proceed: User #{@username} does not have sudo permission.")
      raise Chloride::RemoteError, "User #{@username} does not have sudo permission"
    # This could be a terrible bug.
    elsif data =~ /Sorry, try again./
      # Sudo failed, wrong password. Bail out.
      stream_block.call(info, :stderr, 'Cannot proceed: Sudo password not recognized.')
      raise Chloride::RemoteError, 'Sudo password not recognized'
    end
  end
end
