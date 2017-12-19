# encoding: utf-8
require "logstash/filters/base"
require "logstash/namespace"
require "aws-sdk"
require "lru_redux"

class LogStash::Filters::DynamoEnrich < LogStash::Filters::Base
  config_name "dynamo_enrich"

  config :table_name, :validate => :string, :required => true
  config :region, :validate => :string, :default => ""
  config :primary_key_name, :validate => :string, :required => true
  config :primary_key_value, :validate => :string, :required => true
  config :return_attribute, :validate => :string, :required => true
  config :target, :validate => :string, :required => true
  config :enable_cache, :validate => :boolean, :default => true
  config :cache_ttl, :validate => :number, :default => 300
  config :cache_size, :validate => :number, :default => 1024

  public
  def register
    region_set = @region != ""
    if region_set
      @client = Aws::DynamoDB::Client.new(region: @region)
    else
      @client = Aws::DynamoDB::Client.new()
    end

    if @enable_cache
      @cache = LruRedux::TTL::ThreadSafeCache.new(@cache_size, @cache_ttl)
    end
  end # def register

  public
  def filter(event)
    primary_key_value = event.get(@primary_key_value)
    if @enable_cache && @cache.key?(primary_key_value)
      cached_value = @cache[primary_key_value]
      if cached_value
        event.set(@target, ::LogStash::Util.deep_clone(cached_value))
      else
        event.tag("_dynamoenrichitemnotfound")
      end
    else
      lookup_value = fetch_dynamo(primary_key_value)
      @cache.getset(primary_key_value){lookup_value} if @enable_cache

      if lookup_value
        event.set(@target, ::LogStash::Util.deep_clone(lookup_value))
      else
        event.tag("_dynamoenrichitemnotfound")
      end
    end
    filter_matched(event)
  rescue Aws::DynamoDB::Errors::ServiceError
    event.tag("_dynamoenrichserviceerror")
  end # def filter

  def fetch_dynamo(primary_key_value)
    resp = @client.get_item({
      key: {
        @primary_key_name => {
          s: primary_key_value,
        },
      }, 
      table_name: @table_name, 
    })

    if resp.item && !resp.item.empty?
      return resp.item[@return_attribute]
    end
    # return false
  end
end # class LogStash::Filters::DynamoEnrich
