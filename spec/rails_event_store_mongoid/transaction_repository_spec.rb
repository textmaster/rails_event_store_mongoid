require 'spec_helper'
require 'ruby_event_store'
require 'ruby_event_store/spec/event_repository_lint'

describe RailsEventStoreMongoid::TransactionRepository do
  subject { described_class.new adapter: RailsEventStoreMongoid::Transaction }
  let(:stream_name) { 'test_stream' }

  it_behaves_like :event_repository

  specify 'initialize with adapter' do
    repository = described_class.new
    expect(repository.adapter).to eq(RailsEventStoreMongoid::Transaction )
  end

  specify 'provide own event implementation' do
    CustomEvent = Class.new
    repository = described_class.new(adapter: CustomEvent)
    expect(repository.adapter).to eq(CustomEvent)
  end

  describe 'event ordering' do
    let(:page_size) { 50 }

    class SomeEvent
      attr_reader :event_id
      def initialize(event_id: SecureRandom.uuid, metadata: nil, data: nil)
        @event_id = event_id
      end
    end

    def event_attrs(**attrs)
      { event_type: 'SomeEvent', id: attrs[:event_id] }.merge(attrs)
    end

    def create_event(event_id:, stream: stream_name)
      RailsEventStoreMongoid::Transaction.create!(
        events: [event_attrs(event_id: event_id)],
        stream: stream,
      )
    end

    def create_events(events: [], stream: stream_name)
      RailsEventStoreMongoid::Transaction.create!(
        events: events.map { |e| event_attrs(**e) },
        stream: stream,
      )
    end

    before do
      create_event(event_id: 'event2')

      create_events(events: [
        { event_id: 'event1'},
        { event_id: 'event4'},
      ])

      create_event(event_id: 'event20', stream: 'other_stream')

      create_events(events: [
        { event_id: 'event5'},
        { event_id: 'event3'},
      ])
    end

    specify '#last_stream_event' do
      expect(subject.last_stream_event(stream_name).event_id).to eq('event3')
    end

    specify '#read_events_forward' do
      expect(subject.read_events_forward(stream_name, 'event1', page_size).map(&:event_id)).to eq(%w{event4 event5 event3})
    end

    specify '#read_events_backward' do
      expect(subject.read_events_backward(stream_name, 'event5', page_size).map(&:event_id)).to eq(%w{ event4 event1 event2})
    end

    specify '#read_stream_events_forward' do
      expect(subject.read_stream_events_forward(stream_name).map(&:event_id)).to eq(%w{event2 event1 event4 event5 event3})
    end

    specify '#read_stream_events_backward' do
      expect(subject.read_stream_events_backward(stream_name).map(&:event_id)).to eq(%w{event3 event5 event4 event1 event2})
    end

    specify '#read_all_streams_backward' do
      expect(subject.read_all_streams_backward('event5', page_size).map(&:event_id)).to eq(%w{event20 event4 event1 event2})
    end

    specify '#read_all_streams_forward' do
      expect(subject.read_all_streams_forward('event4', page_size).map(&:event_id)).to eq(%w{event20 event5 event3})
    end
  end

  describe "with_lock" do
    it "yields to the block" do
      expect { |b| subject.with_lock(stream_name, &b) }.to yield_control
    end
  end
end
