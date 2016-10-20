require 'thread'
require 'facter'
require 'optparse'
require 'puppet/indirector/face'
require 'puppet/util/terminal'
require 'puppet/util/colors'

require 'chloride/host'
require 'chloride/action'
require 'chloride/action/execute'

@config = {}
@config['arguments'] = nil

@config['credentials'] = nil
@config['sudo'] = true
@config['threads'] = 2

@config['script'] = 'foo.sh'

@config['nodes'] = 'nodes.txt'

thread_count    = options[:threads].to_i
completed_nodes = []
failed_nodes    = []
results         = []
mutex           = Mutex.new

thread_count.times.map {
  Thread.new(nodes,completed_nodes,options) do |nodes,completed_nodes,options|
    while target = mutex.synchronize { nodes.pop }
      Puppet.notice("Processing target: #{target}")
      begin
        node = Chloride::Host.new(target,@config)
        node.ssh_connect
        Puppet.debug("SSH status: #{node.ssh_status}")
        if [:error,:disconnected].include? node.ssh_status
          mutex.synchronize { failed_nodes  << Hash[target => node.ssh_connect.to_s] }
          next
        end
        # Allow user to pass in -s arguments as hash and reformate for
        # bash to parse them via the -s, such as the csr_attributes
        # custom_attributes:challengePassword=S3cr3tP@ssw0rd
        bash_arguments = @config[:arguments].map{|k,v| "#{v.map{|_k,_v| "%s:%s=%s" % [k,_k,_v]}.join(" ")}"}.unshift("-s").join(" ") unless @config[:arguments].nil?
        install = Chloride::Action::Execute.new(
          :host => node,
          :sudo => options[:sudo],
          :cmd  => "touch chloride_was_here")
         install.go do |event|
           event.data[:messages].each do |data|
             Puppet::Util::Log.with_destination(:syslog) do
               message = [
                 target,
                 data.message,
               ].join(' ')
               # We lose exit codes with curl | bash  so curl errors must
               # be scraped out of the message in question. We could do
               # the curl seperately and then the install in later
               # versions of this code to catch curl errors better
               curl_errors = [
                 /Could not resolve host:.*; Name or service not known/,
                 /^.*curl.*(E|e)rror/
               ]
               re = Regexp.union(curl_errors)
               severity = data.message.match(re) ? :err : data.severity
               Puppet::Util::Log.newmessage(Puppet::Util::Log.new(:level => severity, :message => message))
             end
           end
         end
         if install.success?
           mutex.synchronize { completed_nodes << Hash[target => install.results[target][:exit_status]] }
         else
           mutex.synchronize { failed_nodes    << Hash[target => install.results[target][:exit_status]] }
           Puppet.err "Node: #{target} failed"
         end
      rescue Exception => e
        Puppet.err("target:#{target} error:#{e.to_s}")
        mutex.synchronize { failed_nodes  << Hash[target => e.to_s] }
      end
    end
  end
}.each(&:join)
results << completed_nodes
results << failed_nodes
puts results.flatten
