require 'spec_helper'
require 'chloride/executor'

describe Chloride::Executor do
  subject { described_class.new(Logger.new('/dev/null')) }

  describe "#execute" do
    let(:executed_events) do
      collected_events = []
      executor = described_class.new(Logger.new('/dev/null')) { |e| collected_events << e }
      executor.execute(steps)
      collected_events
    end

    let(:step1) do
      Chloride::Step::Noop.new(:name => :step1, :r18n => R18n.t)
    end

    let(:step2) do
      Chloride::Step::Noop.new(:name => :step2, :r18n => R18n.t)
    end

    let(:steps) { [step1, step2] }

    it "performs each step" do
      subject.execute(steps)

      expect(step1).to be_performed
      expect(step2).to be_performed
    end

    it "sends a step_start event before each step" do
      allow(subject).to receive(:publish)
      expect(subject).to receive(:publish).with(satisfy { |e| e.type == :step_start && e.name == :step1 }).ordered
      expect(step1).to receive(:perform_step).ordered
      expect(subject).to receive(:publish).with(satisfy { |e| e.type == :step_start && e.name == :step2 }).ordered
      expect(step2).to receive(:perform_step).ordered

      subject.execute(steps)
    end

    shared_examples_for :step_failure do
      it "sends a step_error event" do
        expect(executed_events).to include satisfy { |m| m.type == :step_error && m.name == :step1 }
      end

      it "does not send a step_success event" do
        expect(executed_events).not_to include satisfy { |m| m.type == :step_success && m.name == :step1 }
      end

      it "does not send a step_warn event" do
        expect(executed_events).not_to include satisfy { |m| m.type == :step_warn && m.name == :step1 }
      end

      it "executes the remaining steps if the failed step is not fail-stop" do
        subject.execute(steps)

        expect(step2).to be_performed
      end

      describe "when the step is fail-stop" do
        before :each do
          allow(step1).to receive(:fail_stop?).and_return(true)
        end

        it "does not perform the remaining steps" do
          subject.execute(steps)

          expect(step2).not_to be_performed
        end

        it "sends a step_skip event for the remaining steps" do
          expect(executed_events).to include satisfy { |m| m.type == :step_skip && m.name == :step2 }
        end

        it "does not send a step_start event for the remaining steps" do
          expect(executed_events).not_to include satisfy { |m| m.type == :step_start && m.name == :step2 }
        end

        it "does not send any complete event for the remaining steps" do
          expect(executed_events).not_to include satisfy { |m| m.type == :step_success && m.name == :step2 }
          expect(executed_events).not_to include satisfy { |m| m.type == :step_warn && m.name == :step2 }
          expect(executed_events).not_to include satisfy { |m| m.type == :step_error && m.name == :step2 }
        end
      end
    end

    describe "when a step has status error" do
      before :each do
        step1.error("localhost", "OH NO")
      end

      it_behaves_like :step_failure
    end

    [Chloride::RemoteError, RuntimeError, Timeout::Error].each do |error|
      describe "when a step raises #{error}" do
        before :each do
          allow(step1).to receive(:perform_step).and_raise(error, "Something has gone terribly, horribly awry!")
        end

        it "adds the exception as an error message" do
          event = executed_events.find { |m| m.type == :step_error && m.name == :step1 }
          expect(event.messages).to include satisfy { |m| m.severity == :error && m.message =~ /An error occured while performing.*terribly, horribly awry!/ }
        end

        it_behaves_like :step_failure
      end
    end

    describe "when a step has status warn" do
      before :each do
        step1.warning("localhost", "oh no")
      end

      it "sends a step_warn event" do
        expect(executed_events).to include satisfy { |m| m.type == :step_warn && m.name == :step1 }
      end

      it "does not send a step_success event" do
        expect(executed_events).not_to include satisfy { |m| m.type == :step_success && m.name == :step1 }
      end

      it "does not send a step_error event" do
        expect(executed_events).not_to include satisfy { |m| m.type == :step_error && m.name == :step1 }
      end

      it "executes the remaining steps if the step is not fail-stop" do
        subject.execute(steps)

        expect(step2).to be_performed
      end

      it "executes the remaining steps if the step is fail-stop" do
        subject.execute(steps)

        expect(step2).to be_performed
      end
    end

    describe "when a step has status success" do
      it "sends a step_success event" do
        expect(executed_events).to include satisfy { |m| m.type == :step_success && m.name == :step1 }
      end

      it "does not send a step_error event" do
        expect(executed_events).not_to include satisfy { |m| m.type == :step_error && m.name == :step1 }
      end

      it "does not send a step_warn event" do
        expect(executed_events).not_to include satisfy { |m| m.type == :step_warn && m.name == :step1 }
      end

      it "executes the remaining steps if the step is not fail-stop" do
        subject.execute(steps)

        expect(step2).to be_performed
      end

      it "executes the remaining steps if the step is fail-stop" do
        subject.execute(steps)

        expect(step2).to be_performed
      end
    end

    it "includes the step's messages on its completed event" do
      step1.info("localhost", "AW YEAH")

      event = executed_events.find { |m| m.type == :step_success && m.name == :step1 }

      expect(event.messages.map(&:message)).to eq ["AW YEAH"]
    end

    it "resets the step when completed" do
      step1.error("localhost", "OH NO")

      subject.execute(steps)

      expect(step1.messages).to be_empty
      expect(step1.status).to eq(:success)
    end
  end
end
