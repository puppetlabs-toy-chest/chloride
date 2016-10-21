require 'spec_helper'
require 'chloride/step'

describe Chloride::Step do

  subject { described_class.new() }

  it "defaults to status success" do
    expect(subject.status).to eq :success
  end

  it "has status success after receiving an info" do
    subject.info('localhost', 'hi step')

    expect(subject.status).to eq :success
  end

  it "has status warn after receiving a warning" do
    subject.warning('localhost', 'oh no step')

    expect(subject.status).to eq :warn
  end

  it "has status error after receiving an error" do
    subject.error('localhost', 'OH NO STEP')

    expect(subject.status).to eq :error
  end

  it "has status error after receiving a warning then an error" do
    subject.warning('localhost', 'oh no step')
    subject.error('localhost', 'OH NO STEP')

    expect(subject.status).to eq :error
  end

  it "has status error after receiving an error then a warning" do
    subject.error('localhost', 'OH NO STEP')
    subject.warning('localhost', 'oh no step')

    expect(subject.status).to eq :error
  end
end
