require 'spec_helper'
require 'chloride/action/execute'

describe Chloride::Action::Execute do
  describe '#go' do
    subject { described_class.new(hosts: [host_a, host_b], cmd: cmd) }

    let(:cmd) { '/bin/echo hello' }
    let(:host_a) { Chloride::Host.new('a') }
    let(:host_b) { Chloride::Host.new('b') }

    it 'execute the command on the specified hosts' do
      expect(host_a).to receive(:execute)
      expect(host_b).to receive(:execute)

      subject.go {}
    end

    it 'returns results per-host' do
      expect(host_a).to receive(:execute).with(cmd, false).and_return(exit_status: 0)
      expect(host_b).to receive(:execute).with(cmd, false).and_return(exit_status: 1)
      results = subject.go {}

      expect(results['a']).to eq(exit_status: 0)
      expect(results['b']).to eq(exit_status: 1)
    end

    it 'executes the command with sudo if requested' do
      execute = described_class.new(hosts: [host_a, host_b], cmd: cmd, sudo: true)

      expect(host_a).to receive(:execute).with(cmd, true).and_return(exit_status: 0)
      expect(host_b).to receive(:execute).with(cmd, true).and_return(exit_status: 1)
      execute.go {}
    end

    it 'is successful if the command was successful on all hosts' do
      expect(host_a).to receive(:execute).with(cmd, false).and_return(exit_status: 0)
      expect(host_b).to receive(:execute).with(cmd, false).and_return(exit_status: 0)
      subject.go {}

      expect(subject).to be_success
    end

    it 'is not successful if the command was successful on any host' do
      expect(host_a).to receive(:execute).with(cmd, false).and_return(exit_status: 0)
      expect(host_b).to receive(:execute).with(cmd, false).and_return(exit_status: 1)
      subject.go {}

      expect(subject).not_to be_success
    end
  end
end
