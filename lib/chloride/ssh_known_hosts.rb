# Dummy KnownHosts implementation
#
# This exists to stop Net::SSH from writing to the user's known_hosts file
# Instead, new host signatures are saved to a library-specific file.
class Chloride::SSHKnownHosts < Net::SSH::KnownHosts
  # Method signatures inherited from Net::SSH::KnownHosts
  # def initialize(source)
  # def hostfiles(options, which=:all)
  # def search_in(files, host)
  # def keys_for(host)
  # def known_host_hash?(hostlist, entries, scanner)
  # def add(host, key)
  # def add(host, key, options={})

  # Must be implemented
  def search_for(host, options = {})
    opts = {}.merge(options).merge(user_known_hosts_file: source)
    Net::SSH::KnownHosts.search_for(host, opts)
  end
end
