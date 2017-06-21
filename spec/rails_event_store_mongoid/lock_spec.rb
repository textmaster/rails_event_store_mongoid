require 'spec_helper'

RSpec.describe RailsEventStoreMongoid::Lock do
  subject(:lock) { described_class.new }
  let(:stream_name) { "foo" }

  def obtain_lock(&block)
    lock.with_lock(stream_name, &block)
  end
  describe "#with_lock" do

    it "yields to the block" do
      expect {|b| obtain_lock(&b) }.to yield_control
    end

    it "allows sequential access" do
      expect {|b| obtain_lock(&b) }.to yield_control
      expect {|b| obtain_lock(&b) }.to yield_control
      expect {|b| obtain_lock(&b) }.to yield_control
    end

    context "when already locked" do
      let(:thread) {
        Thread.new do
          lock.with_lock(stream_name) do
            Thread.stop
          end
        end
      }
      before do
        sleep 0.1 while thread.status != 'sleep'
      end

      after do
        # Release lock
        thread.run
        thread.join
      end

      it "raises a CannotObtainLock exception" do
        expect { obtain_lock {} }.to raise_error(RailsEventStoreMongoid::CannotObtainLock)
      end

      it "doesn't yield" do
        expect { |b| obtain_lock(&b) rescue nil }.to_not yield_control
      end
    end
  end
end
