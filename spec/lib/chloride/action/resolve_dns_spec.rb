require 'spec_helper'
require 'chloride/action/resolve_dns'

describe Chloride::Action::ResolveDNS do
  describe '#go' do
    describe "without a 'from' node" do
      subject { described_class.new(address: 'the-address') }

      it 'uses the ruby DNS resolver' do
        expect(Resolv).to receive(:getaddress).with('the-address').and_return('1.2.3.4')
        subject.go {}
      end

      it 'is successful if DNS resolves' do
        allow(Resolv).to receive(:getaddress).with('the-address').and_return('1.2.3.4')
        subject.go {}

        expect(subject).to be_success
      end

      it 'is not successful if DNS fails to resolve' do
        allow(Resolv).to receive(:getaddress).and_raise(Resolv::ResolvError, 'no address for the-address')
        subject.go {}

        expect(subject).not_to be_success
      end
    end

    describe 'between nodes' do
      let(:from) { double('from') }
      subject { described_class.new(from: from, address: 'the-address') }

      it 'uses getent to resolve DNS' do
        expect(from).to receive(:execute).with('getent hosts the-address').and_return(exit_status: 0)
        subject.go {}
      end

      it 'is successful if DNS resolve' do
        allow(from).to receive(:execute).and_return(exit_status: 0)
        subject.go {}

        expect(subject).to be_success
      end

      it 'is not successful if DNS fails to resolve' do
        allow(from).to receive(:execute).and_return(exit_status: 1)
        subject.go {}

        expect(subject).not_to be_success
      end

      it 'is not successful if the command has an error' do
        allow(from).to receive(:execute).and_raise(Timeout::Error)
        expect { subject.go {} }.to raise_error(Chloride::RemoteError)
      end
    end
  end
end
