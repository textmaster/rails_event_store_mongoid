require 'mongoid'

module RailsEventStoreMongoid
  class Transaction
    include ::Mongoid::Document
    include ::Mongoid::Timestamps::Created::Short

    store_in collection: 'event_store_transactions'

    field :stream, type: String
    field :ts, type: BSON::Timestamp, default: -> { BSON::Timestamp.new(0, 0) }

    embeds_many :events, class_name: 'RailsEventStoreMongoid::TransactionEvent' do
      def after(event_id)
        events = to_a
        start = events.index {|e| e.event_id == event_id }
        count = events.count - (start + 1)
        events.slice(start + 1, count)
      end

      def before(event_id)
        events = to_a
        finish = events.index {|e| e.event_id == event_id }
        return [] if finish == 0
        events.slice(0, finish).reverse
      end
    end

    def last_event
      events.last
    end

    def last_snapshot
      events.reverse.find(&:snapshot)
    end

    class << self
      def build(**attrs)
        self.new(**attrs)
      end

      def for_stream(stream_name)
        where(stream: stream_name)
      end

      def with_event(event_id)
        where(events: { '$elemMatch': { event_id: event_id } })
      end

      def last_snapshot(stream:)
        tx = last_snapshot_transaction(stream: stream)
        return nil unless tx.present?
        tx.last_snapshot
      end

      def last_snapshot_transaction(stream:)
        for_stream(stream).desc(:ts).where(events: { '$elemMatch': { snapshot: true } }).first
      end

      def last_transaction(stream:)
        where(stream: stream).desc(:ts).first
      end

      def last_stream_event(stream:)
        tx = last_transaction(stream: stream)
        return nil unless tx.present?
        tx.last_event
      end
    end

    index({ 'events.event_id': 1 }, { unique: true })
    index(stream: 1, ts: 1)
    # What is the index I want?
    # index({ stream: 1, ts: 1}, { partialFilterExpress: { 'events.snapshot': true } })

  end
end
