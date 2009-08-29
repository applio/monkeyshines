require 'active_support/core_ext/class/inheritable_attributes'
require 'time'
require 'monkeyshines/utils/union_interval'
module Monkeyshines
  module ScrapeJob

    #
    # Paginated lets you make repeated requests to collect a timeline or
    # collection of items.
    #
    # You will typically want to set the
    #
    # A Paginated-compatible ScrapeRequest should inherit from or be compatible
    # with +Monkeyshines::ScrapeRequest+ and additionally define
    # * [#items]  list of individual items in the response; +nil+ if there was an
    #   error, +[]+ if the response was well-formed but returned no items.
    # * [#num_items] number of items from this response
    # * [#span] the range of (typically) IDs within this scrape. Used to know when
    #   we've reached results from previous session
    #
    #
    module Paginated
      #
      # Generates request for each page to be scraped.
      #
      # The includer must define a #create_request(page, pageinfo) method.
      #
      # * request is generated
      # * ... and yielded to the call block. (which must return the fulfilled
      #   scrape_request response.)
      # * after_fetch method chain invoked
      #
      # Scraping stops when is_last?(response, page) is true
      #
      def each_request pageinfo={}, &block
        before_pagination()
        (1..hard_request_limit).each do |page|
          request = create_request(page, pageinfo)
          response = yield request
          after_fetch(response, page)
          break if is_last?(response, page)
        end
        after_pagination()
      end

      # return true if the next request would be pointless (true if, perhaps, the
      # response had no items, or the API page limit is reached)
      def is_last? response, page
        ( (page >= max_pages) ||
          (response && response.healthy? && (response.num_items < items_per_page)) )
      end

      # Bookkeeping/setup preceding pagination
      def before_pagination
      end

      # Finalize bookkeeping at conclusion of scrape_job.
      def after_pagination
      end

      # Feed back info from the fetch
      def after_fetch response, page
      end

      #
      # Soft limit on the number of pages to scrape.
      #
      # Typically, leave this set to the hard_request_limit if you don't know
      # beforehand how many pages to scrape, and override is_last? to decide when
      # to stop short of the API limit
      #
      def max_pages
        hard_request_limit
      end

      # inject class variables
      def self.included base
        base.class_eval do
          # Hard request limit: do not in any case exceed this number of requests
          class_inheritable_accessor :hard_request_limit
          # max items per page the API might return
          class_inheritable_accessor :items_per_page
          # Span of items gathered in this scrape scrape_job.
          attr_accessor :sess_items, :sess_span, :sess_timespan
        end
      end
    end # module Paginated

    #
    # Scenario: you request paginated search requests with a limit parameter (a
    # max_id or min_id, for example).
    #
    # * request successive pages,
    # * use info on the requested page to set the next limit parameter
    # * stop when max_pages is reached or a successful request gives fewer than
    #   items_per_page
    #
    #
    # The first
    #
    #    req?min_id=1234&max_id=
    #    => [ [8675, ...], ..., [8012, ...] ] # 100 items
    #    req?min_id=1234&max_id=8011
    #    => [ [7581, ...], ..., [2044, ...] ] # 100 items
    #    req?min_id=1234&max_id=2043
    #    => [ [2012, ...], ..., [1234, ...] ] #  69 items
    #
    # * The search terminates when
    # ** max_requests requests have been made, or
    # ** the limit params interval is zero,    or
    # ** a successful response with fewer than items_per_page is received.
    #
    # * You will want to save <req?min_id=8676&max_id=""> for later scrape
    #
    module PaginatedWithLimit

      # Set up bookkeeping for pagination tracking
      def before_pagination
        self.sess_items    ||= 0
        self.sess_span       = UnionInterval.new
        self.sess_timespan   = UnionInterval.new
        super
      end

      def after_pagination
        self.prev_items    = prev_items.to_i + sess_items.to_i
        self.prev_span     = sess_span       + prev_span
        self.new_items     = sess_items.to_i + new_items.to_i
        self.sess_items    = 0
        self.sess_span     = UnionInterval.new
        super
      end

      # Return true if the next request would be pointless (true if, perhaps, the
      # response had no items, or the API page limit is reached)
      def is_last? response, page
        unscraped_span.empty? || super(response, page)
      end

      #
      # Feed back info from the scrape
      #
      def after_fetch response, page
        super response, page
        return unless response && response.items
        count_new_items response
        update_spans response
      end

      # inject class variables
      def self.included base
        base.class_eval do
          attr_accessor :new_items
          # include Monkeyshines::Paginated
        end
      end
    end

  end
end
