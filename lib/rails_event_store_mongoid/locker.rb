require 'rails_event_store_mongoid/lock'

module RailsEventStoreMongoid
  class Locker
    def initialize(adapter: ::RailsEventStoreMongoid::Lock.new)
      @adapter = adapter
    end

    def with_lock(stream, &block)
      begin
        retry_count = 0
        @adapter.with_lock(stream, &block)
      rescue CannotObtainLock
        retry_count += 1
        if retry_count < 5
          sleep(0.5)
          retry
        else
          raise
        end
      end
    end

  end
end
