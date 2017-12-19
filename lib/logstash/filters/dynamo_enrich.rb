# encoding: utf-8
require "logstash/filters/base"
require "logstash/namespace"
require "aws-sdk-dynamodb"

class LogStash::Filters::DynamoEnrich < LogStash::Filters::Base
  config_name "dynamo_enrich"

  config :table_name, :validate => :string, :required => true
  config :region, :validate => :string, :default => ""
  config :primary_key_name, :validate => :string, :required => true
  config :primary_key_value, :validate => :string, :required => true
  config :return_attribute, :validate => :string, :required => true
  config :target, :validate => :string, :required => true

  public
  def register
    region_set = @region != ""
    if region_set
      @client = Aws::DynamoDB::Client.new(region: @region)
    else
      @client = Aws::DynamoDB::Client.new()
    end
  end # def register

  public
  def filter(event)

    resp = @client.get_item({
      key: {
        @primary_key_name => {
          s: @primary_key_value, 
        },
      }, 
      table_name: @table_name, 
    })

    if resp.item && !resp.item.empty?
      target_value = resp.item[@return_attribute]
      event.set(@target, ::LogStash::Util.deep_clone(target_value))
    else
      event.tag("_dynamoenrichitemnotfound")
    end

    # filter_matched should go in the last line of our successful code
    filter_matched(event)
  rescue Aws::DynamoDB::Errors::ServiceError
    event.tag("_dynamoenrichserviceerror")
  end # def filter
end # class LogStash::Filters::DynamoEnrich
