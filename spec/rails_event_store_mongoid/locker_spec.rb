require 'spec_helper'

RSpec.describe RailsEventStoreMongoid::Locker do
  let(:timeout) { 1 }
  let(:retry_interval) { 0.1 }
  let(:adapter) { double 'Adapter' }
  subject(:locker) { described_class.new timeout: timeout, retry_interval: retry_interval, adapter: adapter }

  def obtain_lock(&block)
    locker.with_lock(stream_name, &block)
  end
  describe "#with_lock" do
    let(:stream) { 'foo' }
    let(:block) { Proc.new { } }

    it "Obtains the lock through the adapter" do
      expect(adapter).to receive(:with_lock).with(stream)
      locker.with_lock(stream, &block)
    end

    context "cannot obtain lock" do

      context "within the timeout" do
        it "retries" do
          expect(adapter).to receive(:with_lock).and_raise(RailsEventStoreMongoid::CannotObtainLock).ordered
          expect(adapter).to receive(:with_lock).and_raise(RailsEventStoreMongoid::CannotObtainLock).ordered
          expect(adapter).to receive(:with_lock).and_raise(RailsEventStoreMongoid::CannotObtainLock).ordered
          expect(adapter).to receive(:with_lock).ordered
          locker.with_lock(stream, &block)
        end
      end

      context "when the timeout expires" do
        it "raise the CannotObtainLock error" do
          start = Time.new
          expect(Time).to receive(:now).and_return(start).ordered
          expect(Time).to receive(:now).and_return(start + timeout + 1).ordered

          expect(adapter).to receive(:with_lock).and_raise(RailsEventStoreMongoid::CannotObtainLock).once

          expect {
            locker.with_lock(stream, &block)
          }.to raise_error(RailsEventStoreMongoid::CannotObtainLock)
        end
      end

    end
  end
end
