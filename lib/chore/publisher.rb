module Chore
  class Publisher
    DEFAULT_OPTIONS = { :encoder => JsonEncoder }

    attr_accessor :options

    def initialize(opts={})
      self.options = DEFAULT_OPTIONS.merge(opts)
    end

    def publish(job)
      raise NotImplementedError
    end
  protected

    def encode_job(job)
      options[:encoder].encode(job)
    end

  end
end