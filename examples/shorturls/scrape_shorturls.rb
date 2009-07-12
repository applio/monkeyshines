#!/usr/bin/env ruby
require 'rubygems'
$: << File.dirname(__FILE__)+'/../../lib'; $: << File.dirname(__FILE__)
require 'wukong'
require 'monkeyshines'
require 'monkeyshines/scrape_store/read_thru_store'
require 'monkeyshines/scrape_engine/http_head_scraper'
require 'shorturl_request'
require 'shorturl_sequence'
require 'trollop' # gem install trollop

opts = Trollop::options do
  opt :from,      "Flat file of scrapes",                      :type => String
  opt :store_db,  "Tokyo cabinet db name",                     :type => String
  opt :create_db, "Create Tokyo cabinet if --store-db doesn\'t exist?", :type => String
  opt :skip,      "Initial requests to skip ahead",            :type => Integer
  opt :base_url,  "First part of URL incl. scheme and trailing slash, eg http://tinyurl.com/", :type => String
  opt :min_limit, "Smallest sequential URL to randomly visit", :type => Integer
  opt :max_limit, "Largest sequential URL to randomly visit",  :type => Integer
  opt :encoding_radix, "Modulo for turning int index into tinyurl string",  :type => Integer
end

# Request stream
#request_stream = Monkeyshines::FlatFileRequestStream.new_from_command_line(opts, :request_klass => ShorturlRequest)
# request_stream = SequentialUrlRequestStream.new('http://tinyurl.com/', ('aaaaaa'..'lszzzz'))

# nohup ./scrape_shorturls.rb --base-url='http://tinyurl.com/' --max-limit=1200000000 --min-limit=200000000 --create-db=true --store-db rawd/shorturl_scrapes-sequential-`datename`.tdb >> log/shorturl_scrapes-sequential-`datename`.log &
request_stream = RandomSequentialUrlRequestStream.new_from_command_line opts, :request_klass => ShorturlRequest

# Scrape Store
store = Monkeyshines::ScrapeStore::ReadThruStore.new_from_command_line opts

# Scraper
scraper = Monkeyshines::ScrapeEngine::HttpHeadScraper.new

# Bulk load into read-thru cache.
Monkeyshines.logger.info "Beginning scrape itself"
Monkeyshines.log_every 10, :scrape_request, :starting_at => opts[:skip]
request_stream.each do |scrape_request|
  # next if scrape_request.url =~ %r{\Ahttp://(poprl.com|short.to|timesurl.at)}
  result = store.set( scrape_request.url ){ scraper.get(scrape_request) }
  Monkeyshines.log_occasional(:scrape_request){|iter| [iter, store.size, scrape_request.response_code, result, scrape_request.url].join("\t") }
  # sleep 0.1
end
store.close
scraper.finish
