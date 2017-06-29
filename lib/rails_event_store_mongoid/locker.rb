require 'rails_event_store_mongoid/lock'

module RailsEventStoreMongoid
  class Locker
    attr_reader :adapter, :timeout, :retry_interval

    def initialize(timeout: 10, retry_interval: 0.1, adapter: ::RailsEventStoreMongoid::Lock.new)
      @timeout = timeout
      @retry_interval = retry_interval
      @adapter = adapter
    end

    def with_lock(stream, &block)
      begin
        start = Time.now
        adapter.with_lock(stream, &block)
      rescue CannotObtainLock
        if (Time.now - start) < timeout
          sleep(retry_interval)
          retry
        else
          raise
        end
      end
    end

  end
end
