require 'chloride/errors'
require 'chloride/action'

# Executes a shell command on the hosts provided. Will block until completion.
class Chloride::Action::DetectPlatform < Chloride::Action
  attr_reader :results, :hosts

  # TODO: Document args
  def initialize(args)
    super

    @hosts = args[:hosts] || [args[:host]]
  end

  # TODO: Document block format
  def go(&stream_block)
    @status = :running
    @results = Hash.new { |h, k| h[k] = {} }
    @hosts.each do |host|
      # First try identifying using lsb_release.  This takes care of Ubuntu (lsb-release is part of ubuntu-minimal).
      lsb = exec_and_log(host, 'lsb_release -icr', true, @results[host.hostname], &stream_block)

      if (lsb[:exit_status]).zero?
        lsb_data = {}
        lsb[:stdout].each_line do |l|
          k, v = l.split(':')
          lsb_data[k.strip] = v.strip if k && v
        end

        distribution = lsb_data['Distributor ID'].downcase.gsub(/\s+/, '')
        distribution = case distribution
                       when /redhatenterpriseserver|redhatenterpriseclient|redhatenterpriseas|redhatenterprisees|enterpriseenterpriseserver|redhatenterpriseworkstation|redhatenterprisecomputenode|oracleserver/
                         :rhel
                       when /enterprise.*/
                         :centos
                       when /scientific|scientifics|scientificsl/
                         :rhel
                       when /amazonami/
                         :amazon
                       when /suselinux/
                         :sles
                       else
                         distribution.to_sym
        end

        release = lsb_data['Release'].gsub(/\s+/, '')
        release = case distribution
                  when :centos, :rhel
                    release.split('.')[0]
                  when :debian
                    if release == 'testing'
                      '7'
                    else
                      release.split('.')[0]
                    end
                  else
                    release
        end
      end

      # Check for Redhat
      if !distribution && !release
        redhat_release = exec_and_log(host, 'cat /etc/redhat-release', true, @results[host.hostname], &stream_block)

        if (redhat_release[:exit_status]).zero?
          stdout = redhat_release[:stdout]

          distribution = case stdout
                         when /red hat enterprise/im
                           :rhel
                         when /centos/im
                           :centos
                         when /scientific/im
                           :rhel
          end

          release = /.* release ([[:digit:]]).*/.match(stdout)[1]
        end
      end

      # Check for Cumulus
      if !distribution && !release
        os_release = exec_and_log(host, 'cat /etc/os-release', true, @results[host.hostname], &stream_block)

        if (os_release[:exit_status]).zero?
          stdout = os_release[:stdout]

          distribution = :cumulus if /Cumulus Linux/m.match(stdout)
          release = /VERSION_ID=(\d+\.\d)/.match(stdout)[1] if distribution
        end
      end

      # Check for EOS
      if !distribution && !release
        eos_release = exec_and_log(host, 'cat /etc/Eos-release', true, @results[host.hostname], &stream_block)

        if (eos_release[:exit_status]).zero?
          stdout = eos_release[:stdout]

          distribution = :eos if /Arista Networks EOS/m.match(stdout)

          release = /^Arista Networks EOS v*(.*)\..*$/.match(stdout)[1]
        end
      end

      # Check for Debian
      if !distribution && !release
        debian_version = exec_and_log(host, 'cat /etc/debian_version', true, @results[host.hostname], &stream_block)

        if (debian_version[:exit_status]).zero?
          stdout = debian_version[:stdout]
          distribution = :debian

          release = case stdout
                    when /^[[:digit:]]/
                      stdout.split('.')[0]
                    when /^wheezy/.match(stdout)
                      '7'
          end
        end
      end

      # Check for SuSE
      if !distribution && !release
        suse_release = exec_and_log(host, 'cat /etc/SuSE-release', true, @results[host.hostname], &stream_block)

        if (suse_release[:exit_status]).zero?
          stdout = suse_release[:stdout]

          if /Enterprise Server/.match(stdout)
            distribution = :sles
            release = /^VERSION = (\d*)/m.match(stdout)[1]
          end
        end
      end

      # Check for Amazon 6, or fail
      if !distribution && !release
        system_release = exec_and_log(host, 'cat /etc/system-release', true, @results[host.hostname], &stream_block)

        if (system_release[:exit_status]).zero?
          stdout = system_release[:stdout]

          if /amazon linux/im.match(stdout)
            distribution = :amazon
            # How is this safe to assume?
            release = '6'
          end
        end
      end

      # Check for Solaris
      if !distribution && !release
        uname = exec_and_log(host, 'uname -s', true, @results[host.hostname], &stream_block)

        if (uname[:exit_status]).zero?
          distribution = case uname.results[hostname][:stdout].strip
                         when 'SunOS'
                           unamer = exec_and_log(host, 'uname -r', true, @results[host.hostname], &stream_block)

                           if (unamer[:exit_status]).zero?
                             release = unamer.results[hostname][:stdout].split('.')[0]
                           end

                           :solaris
                         when 'AIX'
                           oslevel = exec_and_log(host, 'oslevel', true, @results[host.hostname], &stream_block)
                           yield oslevel

                           if (oslevel[:exit_status]).zero?
                             release = oslevel.results[hostname][:stdout].split('.')[0..1].join('.')
                           end

                           :aix
          end
        end
      end

      # Architecture
      unamem = exec_and_log(host, 'uname -m', true, @results[host.hostname], &stream_block)

      if (unamem[:exit_status]).zero?
        architecture = unamem[:stdout].strip

        architecture = case architecture
                       when 'i686'
                         'i386'
                       when 'ppc'
                         'powerpc'
                       when 'x86_64'
                         [:ubuntu, :debian].include?(distribution) ? 'amd64' : 'x86_64'
                       else
                         architecture
        end
      end

      host.data[:os] = {}
      # Tag
      @results[host.hostname][:distribution] = host.data[:os][:distribution] = distribution
      @results[host.hostname][:release] = host.data[:os][:release] = release
      @results[host.hostname][:architecture] = host.data[:os][:architecture] = architecture

      tag_distribution = distribution || 'unknown'
      tag_release = release || 'unknown'
      tag_architecture = architecture || 'unknown'

      @results[host.hostname][:tag] = host.data[:os][:tag] = case distribution
                                                             when :rhel, :centos, :amazon
                                                               "el-#{tag_release}-#{tag_architecture}"
                                                             else
                                                               "#{tag_distribution}-#{tag_release}-#{tag_architecture}"
      end
    end

    @results
  end

  def success?
    @results.all? do |host, result|
      !(result[:distribution].nil? || result[:release].nil? || result[:architecture].nil?)
    end
  end

  def error_message(hostname)
    if @results.key?(hostname) && @results[hostname].key?(:stderr)
      @results[hostname][:stderr].strip
    end
  end

  def name
    :detect_platform
  end

  def description
    "Detect OS on #{@hosts.join(', ')}"
  end
end
