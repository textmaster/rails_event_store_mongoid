module RailsEventStoreMongoid
  class TransactionRepository
    attr_reader :adapter, :locker

    def initialize(adapter: ::RailsEventStoreMongoid::Transaction, locker: ::RailsEventStoreMongoid::Locker.new)
      @adapter = adapter
      @locker = locker
    end

    def with_lock(stream_name, &block)
      locker.with_lock(stream_name) do
        transaction(stream_name, &block)
      end
    end

    def transaction(stream_name)
      raise "Already in transaction" if in_transaction?
      start_transaction(stream_name)
      yield
      commit_transaction
    end

    def create(event, stream_name)
      if in_transaction?
        assert_transaction_matches_stream(stream_name)
        transaction_object.events.build build_event_model(event)
      else
        create_transaction([event], stream_name)
      end
      event
    end

    def create_snapshot(snapshot, stream_name)
      if in_transaction?
        assert_transaction_matches_stream(stream_name)
        transaction_object.events.build build_snapshot_model(snapshot)
      else
        adapter.create(
          stream: stream_name,
          events: [build_snapshot_model(snapshot)],
        )
      end
    end

    def create_transaction(events, stream_name)
      adapter.create(
        stream: stream_name,
        events: events.map(&method(:build_event_model)),
      )
    end

    def delete_stream(stream_name)
      condition = {stream: stream_name}
      adapter.destroy_all condition
    end

    def has_event?(event_id)
      adapter.with_event(event_id).exists?
    end

    def last_stream_snapshot(stream_name)
      build_event_entity(adapter.last_snapshot(stream: stream_name))
    end

    def last_stream_event(stream_name)
      build_event_entity(adapter.last_stream_event(stream: stream_name))
    end

    def read_events_forward(stream_name, start_event_id, count)
      read_forwards(adapter.for_stream(stream_name), start_event_id, count)
    end

    def read_events_backward(stream_name, start_event_id, count)
      read_backwards(adapter.for_stream(stream_name), start_event_id, count)
    end

    def read_stream_events_forward(stream_name)
      read_forwards(adapter.where(stream: stream_name), :head)
    end

    def read_stream_events_backward(stream_name)
      read_backwards(adapter.where(stream: stream_name), :head)
    end

    def read_all_streams_forward(start_event_id, count)
      read_forwards(adapter, start_event_id, count)
    end

    def read_all_streams_backward(start_event_id, count)
      read_backwards(adapter, start_event_id, count)
    end

    private

    attr_reader :transaction_object

    def start_transaction(stream_name)
      @transaction_object = adapter.build(stream: stream_name)
    end

    def commit_transaction
      transaction_object.save!
      @transaction_object = nil
    end

    def in_transaction?
      @transaction_object.present?
    end

    def build_event_model(event)
      {
        event_id:   event.event_id,
        event_type: event.class,
        data:       event.data,
        meta:       event.metadata,
      }
    end

    def build_snapshot_model(event)
      build_event_model(event).merge({
        snapshot: true,
      })
    end

    def read_forwards(adapter, start_event_id, count = 0)
      stream = adapter
      unless start_event_id.equal?(:head)
        starting_tx = stream.with_event(start_event_id).first
        starting = starting_tx.events.after(start_event_id)
        stream = stream.where(:ts.gt => starting_tx.ts)
      end
      #TODO: This is count of transactions not count of events
      stream = stream.limit(count) if count > 0

      (starting || []) + stream.asc(:ts).map(&method(:build_event_entities)).flatten(1)
    end

    def read_backwards(adapter, start_event_id, count = nil)
      stream = adapter
      unless start_event_id.equal?(:head)
        starting_tx = adapter.with_event(start_event_id).first
        starting = starting_tx.events.before(start_event_id)
        stream = stream.where(:ts.lt => starting_tx.ts)
      end
      #TODO: This is count of transactions not count of events
      stream = stream.limit(count) if count > 0

      (starting || []) + stream.desc(:ts).map { |t| build_event_entities(t).reverse }.flatten(1)
    end

    def build_event_entity(record)
      return nil unless record
      record.event_type.constantize.new(
        event_id: record.event_id,
        metadata: record.meta.symbolize_keys,
        data: record.data.symbolize_keys,
      )
    end

    def assert_transaction_matches_stream(stream_name)
      raise "Can only modify a single aggregate during a transaction" unless stream_name == transaction_object.stream
    end

    def build_event_entities(transaction)
      transaction.events.map(&method(:build_event_entity))
    end
  end
end
