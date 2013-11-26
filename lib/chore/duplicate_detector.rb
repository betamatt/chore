module Chore
  class DuplicateDetector

    def initialize(opts={})
      # Make it optional. Only required when we use it.
      begin
        require 'dalli'
      rescue LoadError => e
        Chore.logger.error "Unable to load dalli gem. It is required if duplicate \
  detection is enabled.  Install it with 'gem install dalli'."
        raise e
      end

      memcached_options = {
        :auto_eject_hosts    => false,
        :cache_lookups       => false,
        :tcp_nodelay         => true,
        :socket_max_failures => 5,
        :socket_timeout      => 2
      }

      @timeouts         = {}
      @dedupe_strategy  = opts.fetch(:dedupe_strategy) { :relaxed }
      @timeout          = opts.fetch(:timeout) { 0 }
      @servers          = opts.fetch(:servers) { nil }
      @memcached_client = opts.fetch(:memcached_client) { Dalli::Client.new(@servers, memcached_options) }
    end

    def found_duplicate?(msg)
      return false unless msg && msg.respond_to?(:queue) && msg.queue
      timeout = self.queue_timeout(msg.queue)
      begin
        !@memcached_client.add(msg.id, "1",timeout)
      rescue StandardError => e
        case @dedupe_strategy.to_sym
        when :strict
          Chore.logger.error "Error accessing duplicate cache server. Assuming message is a duplicate. #{e}\n#{e.backtrace * "\n"}"
          true
        when :relaxed
          Chore.logger.error "Error accessing duplicate cache server. Assuming message is not a duplicate. #{e}\n#{e.backtrace * "\n"}"
          false
        end
      end
    end

    def queue_timeout(queue)
      @timeouts[queue.url] ||= queue.visibility_timeout || @timeout
    end

  end
end
