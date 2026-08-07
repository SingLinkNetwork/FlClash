# frozen_string_literal: true

client_source = File.read(
  File.expand_path('../lib/views/proxies/common.dart', __dir__),
)
core_source = File.read(
  File.expand_path('../core/common.go', __dir__),
)

client_limit = client_source[/const delayTestBatchSize = (\d+);/, 1]
core_limit = core_source[/WithConcurrencyNum\[bool\]\((\d+)\)/, 1]

abort 'client delay test batch limit is missing' unless client_limit
abort 'core async delay concurrency limit is missing' unless core_limit
abort 'client and core delay concurrency limits must match' unless
  client_limit == core_limit
abort 'delayTest must use the shared batch limit' unless
  client_source.include?('items.batch(delayTestBatchSize)')

puts "delay test concurrency aligned: #{client_limit}"
