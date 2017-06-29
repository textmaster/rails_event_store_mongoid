require 'mongoid'

module RailsEventStoreMongoid
  class Lock
    include Mongoid::Document

    store_in collection: 'event_store_locks'

    field :_id, type: String, default: ->{ SecureRandom.uuid }, overwrite: true
    field :ts, type: Time

    def with_lock(stream)
      begin
        lock = self.class.create(_id: stream, ts: Time.now.utc)
      rescue ::Mongo::Error::OperationFailure
        raise CannotObtainLock
      end
      yield if block_given?
    ensure
      lock.delete if lock.present?
    end

    index({ ts: 1 }, { expire_after_seconds: 30 })
  end
end
