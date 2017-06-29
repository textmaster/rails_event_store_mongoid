require 'mongoid'

module RailsEventStoreMongoid
  class TransactionEvent
    include ::Mongoid::Document

    field :event_id, type: String
    field :event_type, type: String
    field :meta, type: Hash, default: {}
    field :data, type: Hash, default: {}
    field :snapshot, type: Boolean, default: false

    field :ts, type: BSON::Timestamp, default: -> { BSON::Timestamp.new(0, 0) }
    embedded_in :transaction, class_name: 'RailsEventStoreMongoid::Transaction'

  end
end
