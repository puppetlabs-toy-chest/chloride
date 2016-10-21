require 'spec_helper'
require 'chloride/event/message'

describe Chloride::Event::Message do
  describe '#remove_ansi' do
    it 'removes the ANSI color codes' do
      msg = described_class.new(:error, 'test.local.vm', "\e[0;32merror\e[0m")
      expect(msg.remove_ansi(msg.message)).to eq('error')

      msg = described_class.new(:error, 'test.local.vm', "\e[0;32mer\e[0m\e[1;31mror\e[0m")
      expect(msg.remove_ansi(msg.message)).to eq('error')
    end

    it 'removes [m' do
      msg = described_class.new(:error, 'test.local.vm', "\e[0;32mer\e[m\e[1;31mror\e[m")
      expect(msg.remove_ansi(msg.message)).to eq('error')
    end

    it 'does not remove things very similar to ANSI color codes' do
      str = '[0;32merror[0m'
      msg = described_class.new(:error, 'test.local.vm', str)
      expect(msg.remove_ansi(msg.message)).to eq(str)

      str = '[44merror[0m'
      msg = described_class.new(:error, 'test.local.vm', str)
      expect(msg.remove_ansi(msg.message)).to eq(str)

      str = '[12nerror[0n'
      msg = described_class.new(:error, 'test.local.vm', str)
      expect(msg.remove_ansi(msg.message)).to eq(str)

      str = '[12m]nerror[0m]'
      msg = described_class.new(:error, 'test.local.vm', str)
      expect(msg.remove_ansi(msg.message)).to eq(str)

      str = '[magic]error[m100]'
      msg = described_class.new(:error, 'test.local.vm', str)
      expect(msg.remove_ansi(msg.message)).to eq(str)
    end

    it 'does not do anything to regular strings' do
      str = "I'm just a regular old string doing regular old string things."
      msg = described_class.new(:error, 'test.local.vm', str)
      expect(msg.remove_ansi(msg.message)).to eq(str)
    end
  end
end
