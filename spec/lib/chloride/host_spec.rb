require 'spec_helper'
describe Chloride::Host do
  let(:sshtimeout) { 60 }
  describe 'with no roles and a privkey' do
    let(:privkey) { '~/.ssh/superduperkey'}

    subject { described_class.new 'test.vm', {ssh_key_file: privkey} }

    it 'should expand privkey paths' do
      expect(subject.ssh_key_file).to eq(File.expand_path(privkey))
    end
  end

  describe "#ssh_connect" do
    it "does nothing when host is local" do
      host = described_class.new('somewhere', :localhost => true)
      expect(Net::SSH).not_to receive(:start)

      host.ssh_connect
    end

    it "defaults to root" do
      host = described_class.new('somewhere')
      expect(Net::SSH).to receive(:start).with('somewhere', 'root', :timeout => sshtimeout, :logger => an_instance_of(Logger), :verbose => :warn)

      host.ssh_connect
    end

    it "connects to the specified hostname and username with a 60 second timeout" do
      host = described_class.new('somewhere', :username => 'someone')
      expect(Net::SSH).to receive(:start).with('somewhere', 'someone', :timeout => sshtimeout, :logger => an_instance_of(Logger), :verbose => :warn)

      host.ssh_connect
    end

    it "uses an SSH key file if provided" do
      host = described_class.new('somewhere', :username => 'someone', :ssh_key_file => '/root/.ssh/id_rsa')
      expect(Net::SSH).to receive(:start).with('somewhere', 'someone', :timeout => sshtimeout, :keys => ['/root/.ssh/id_rsa'], :logger => an_instance_of(Logger), :verbose => :warn)

      host.ssh_connect
    end

    it "doesn't use a blank SSH key path" do
      host = described_class.new('somewhere', :username => 'someone', :ssh_key_file => '   ')
      expect(Net::SSH).to receive(:start).with('somewhere', 'someone', :timeout => sshtimeout, :logger => an_instance_of(Logger), :verbose => :warn)

      host.ssh_connect
    end

    it "uses an SSH key passphrase if provided" do
      host = described_class.new('somewhere', :username => 'someone', :ssh_key_passphrase => 'super secret')
      expect(Net::SSH).to receive(:start).with('somewhere', 'someone', :timeout => sshtimeout, :passphrase => 'super secret', :logger => an_instance_of(Logger), :verbose => :warn)

      host.ssh_connect
    end

    it "uses a key with a passphrase if both are provided" do
      host = described_class.new('somewhere', :username => 'someone', :ssh_key_file => '/root/.ssh/id_rsa', :ssh_key_passphrase => 'super secret')
      expect(Net::SSH).to receive(:start).with('somewhere', 'someone', :timeout => sshtimeout, :keys => ['/root/.ssh/id_rsa'], :passphrase => 'super secret', :logger => an_instance_of(Logger), :verbose => :warn)

      host.ssh_connect
    end

    it "uses a password if provided" do
      host = described_class.new('somewhere', :username => 'someone', :sudo_password => 'even secreter')
      expect(Net::SSH).to receive(:start).with('somewhere', 'someone', :timeout => sshtimeout, :password => 'even secreter', :logger => an_instance_of(Logger), :verbose => :warn)

      host.ssh_connect
    end

    it "uses a key with a passphrase and user password if provided" do
      host = described_class.new('somewhere', :username => 'someone', :sudo_password => 'watwatwat', :ssh_key_file => '/root/.ssh/id_rsa', :ssh_key_passphrase => 'super secret')
      expect(Net::SSH).to receive(:start).with('somewhere', 'someone', :timeout => sshtimeout, :password => 'watwatwat', :keys => ['/root/.ssh/id_rsa'], :passphrase => 'super secret', :logger => an_instance_of(Logger), :verbose => :warn)

      host.ssh_connect
    end
  end
end
