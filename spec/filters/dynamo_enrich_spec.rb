# encoding: utf-8
require_relative '../spec_helper'
require "logstash/filters/dynamo_enrich"

describe LogStash::Filters::DynamoEnrich do
  describe "Lookup Table" do
    let(:config) do <<-CONFIG
      filter {
        dynamo_enrich {
          table_name => "id_lookup"
          region => "us-east-1"
          primary_key_name => "id"
          primary_key_value => "user_id"
          return_attribute => "name"
          target => "user_name"
          enable_cache => false
        }
      }
    CONFIG
    end
    let(:dynamo_client) { instance_double(Aws::DynamoDB::Client) }
    let(:dynamo_response) { instance_double(Aws::DynamoDB::Types::GetItemOutput) }
  
    before do
      allow(Aws::DynamoDB::Client).to receive(:new).and_return(dynamo_client)
      allow(dynamo_response).to receive(:item).and_return(item)
    end

    context "Item exists" do
      let(:item) { {"name" => "Jane Doe"} }

      before do
        allow(dynamo_client).to receive(:get_item).and_return(dynamo_response)
      end

      sample("user_id" => "123") do
        expect(subject).to include("user_name")
        expect(subject.get('user_name')).to eq('Jane Doe')
      end
    end

    context "Item doesn't exist" do
      let(:item) { {} }

      before do
        allow(dynamo_client).to receive(:get_item).and_return(dynamo_response)
      end

      sample("user_id" => "123") do
        expect(subject.get('tags')).to include('_dynamoenrichitemnotfound')
      end
    end

    context "Dynamo returns a service error" do
      let(:item) { {} }

      before do
        expect(dynamo_client).to receive(:get_item).and_raise(Aws::DynamoDB::Errors::ServiceError.new(Seahorse::Client::RequestContext.new, "Internal Error"))
      end

      sample("user_id" => "123") do
        expect(subject.get('tags')).to include('_dynamoenrichserviceerror')
      end
    end
  end

  describe "Cached result" do
    let(:config) do <<-CONFIG
      filter {
        dynamo_enrich {
          table_name => "id_lookup"
          region => "us-east-1"
          primary_key_name => "id"
          primary_key_value => "user_id"
          return_attribute => "name"
          target => "user_name"
        }
      }
    CONFIG
    end
    let(:dynamo_client) { instance_double(Aws::DynamoDB::Client) }
    let(:dynamo_response) { instance_double(Aws::DynamoDB::Types::GetItemOutput) }
    let(:cache_double) { instance_double(LruRedux::TTL::ThreadSafeCache) }
  
    before do
      allow(Aws::DynamoDB::Client).to receive(:new).and_return(dynamo_client)
      allow(LruRedux::TTL::ThreadSafeCache).to receive(:new).and_return(cache_double)
    end

    context "Item is cached" do
      before do
        allow(cache_double).to receive(:key?).with("123").and_return(true)
        allow(cache_double).to receive(:[]).with("123").and_return("Jane Doe")
      end

      sample("user_id" => "123") do
        expect(dynamo_client).not_to receive(:get_item)
        expect(subject).to include("user_name")
        expect(subject.get('user_name')).to eq('Jane Doe')
      end
    end

    context "Item is not cached" do
      let(:item) { {} }
    
      before do
        allow(cache_double).to receive(:key?).with("123").and_return(false)
        allow(cache_double).to receive(:getset)
        allow(dynamo_response).to receive(:item).and_return(item)
        allow(dynamo_client).to receive(:get_item).and_return(dynamo_response)
      end

      sample("user_id" => "123") do
        expect(cache_double).not_to receive(:[])
        expect(dynamo_client).to receive(:get_item)

        subject
      end
    end
  end

end
