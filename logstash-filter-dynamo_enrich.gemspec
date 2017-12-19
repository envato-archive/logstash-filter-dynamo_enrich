Gem::Specification.new do |s|
  s.name          = 'logstash-filter-dynamo_enrich'
  s.version       = '0.1.0'
  s.licenses      = ['Apache License (2.0)']
  s.summary       = 'A filter plugin to enrich events with data from DynamoDB'
  s.description   = 'Query data from DynamoDB and populate LogStash events with the returned values'
  s.homepage      = 'https://github.com/envato/logstash-filter-dynamo_enrich'
  s.authors       = ['nemski']
  s.email         = 'patrick.robinson@envato.com'
  s.require_paths = ['lib']

  # Files
  s.files = Dir['lib/**/*','spec/**/*','vendor/**/*','*.gemspec','*.md','CONTRIBUTORS','Gemfile','LICENSE','NOTICE.TXT']
   # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "filter" }

  # Gem dependencies
  s.add_runtime_dependency "logstash-core-plugin-api", "~> 2.0"
  s.add_runtime_dependency "aws-sdk-dynamodb", "~> 1.0"
  s.add_development_dependency 'logstash-devutils'
end
