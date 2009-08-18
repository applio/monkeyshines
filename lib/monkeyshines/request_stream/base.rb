module Monkeyshines
  module RequestStream

    #
    # RequestStream::Base
    #
    #
    class Base
      attr_accessor :options
      Base::DEFAULT_OPTIONS = {}
      def initialize _options={}
        self.options = Base::DEFAULT_OPTIONS.deep_merge(_options)
        Monkeyshines.logger.debug "New #{self.class} as #{options.inspect}"
      end

      def each *args, &block
        self.request_store.each(*args) do |*raw_req_args|
          yield request_from_raw(*raw_req_args)
        end
      end

      def put *args
        request_store.put *args
      end
    end
  end
end
