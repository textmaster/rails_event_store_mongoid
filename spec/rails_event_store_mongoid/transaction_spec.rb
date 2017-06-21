require 'spec_helper'

describe RailsEventStoreMongoid::Transaction do
  let(:stream_name) { 'foo' }

  def build_event(event_id = SecureRandom.uuid)
    { event_type: 'SimpleEvent', event_id: event_id, id: event_id }
  end

  def build_snapshot(event_id = SecureRandom.uuid)
    { event_type: 'SimpleEvent', event_id: event_id, id: event_id, snapshot: true }
  end

  def create_transaction(events, stream = stream_name)
    described_class.create(
      events: events,
      stream: stream,
    )
  end

  describe 'class methods' do
    describe '::with_event' do

      describe 'single event' do
        let(:event) { build_event }
        let!(:transaction) { create_transaction([event]) }
        let!(:other_transaction) { create_transaction([build_event]) }

        it "finds the transaction with the event" do
          expect(described_class.with_event(event[:event_id]).first).to eq(transaction)
        end
      end

      describe 'multiple events' do
        let(:event) { build_event }
        let(:event2) { build_event }
        let(:event3) { build_event }
        let!(:transaction) { create_transaction([event3, event, event2]) }
        let!(:other_transaction) { create_transaction([build_event]) }

        it "finds the transaction with the event" do
          expect(described_class.with_event(event[:event_id]).first).to eq(transaction)
        end
      end
    end

    describe '::for_stream' do
      let!(:transaction) { create_transaction([build_event]) }
      let!(:other_transaction) { create_transaction([build_event], stream: 'other_stream') }

      it "finds the transactions for the stream" do
        for_stream = described_class.for_stream(stream_name)
        expect(for_stream.count).to eq(1)
        expect(for_stream.first).to eq(transaction)
      end
    end

    describe '::last_snapshot' do
      let(:snapshot) { build_snapshot }
      let!(:former_snapshot) { create_transaction([build_event, build_snapshot]) }
      let!(:transaction) { create_transaction([build_event, snapshot, build_event]) }
      let!(:other_transaction) { create_transaction([build_event]) }

      it "finds the last snaphot event" do
        expect(described_class.last_snapshot(stream: stream_name)[:event_id]).to eq(snapshot[:event_id])
      end
    end

    describe 'events' do
      let(:event1) { build_event }
      let(:event2) { build_event }
      let(:event3) { build_event }
      let(:event4) { build_event }
      let!(:transaction) { create_transaction([event1, event2, event3, event4]) }

      describe '#after' do
        def after(event)
          transaction.events.after(event[:event_id]).map(&:event_id)
        end
        it "returns events after the given id" do
          expect(after(event1)).to eq([event2[:event_id], event3[:event_id], event4[:event_id]])
          expect(after(event2)).to eq([event3[:event_id], event4[:event_id]])
          expect(after(event3)).to eq([event4[:event_id]])
          expect(after(event4)).to eq([])
        end
      end

      describe '#before' do
        def before(event)
          transaction.events.before(event[:event_id]).map(&:event_id)
        end
        it "returns events before the given id in reverse order" do
          expect(before(event1)).to eq([])
          expect(before(event2)).to eq([event1[:event_id]])
          expect(before(event3)).to eq([event2[:event_id], event1[:event_id]])
          expect(before(event4)).to eq([event3[:event_id], event2[:event_id], event1[:event_id]])
        end
      end
    end
  end
end


