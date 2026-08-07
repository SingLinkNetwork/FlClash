#!/usr/bin/env ruby
# frozen_string_literal: true

root = File.expand_path('..', __dir__)
service = File.read(File.join(root, 'lib', 'core', 'service.dart'))
test = File.read(File.join(root, 'test', 'core', 'service_test.dart'))

checks = {
  'core callback registry exists' => service.include?('class CoreCallbackRegistry'),
  'successful responses remove callbacks immediately' =>
    service.include?('_callbackCompleterMap.take(result.id)'),
  'shutdown clears pending callbacks' =>
    service.include?('_callbackCompleterMap.clear()'),
  'timeout cleanup still removes callbacks' =>
    service.include?('final pending = _callbackCompleterMap.take(id)'),
  'callback cleanup has regression tests' =>
    test.include?('removes completed core callbacks') &&
      test.include?('clears pending callbacks'),
}

failed = checks.each_with_object([]) do |(name, passed), names|
  names << name unless passed
end
abort "Core callback cleanup verifier failed: #{failed.join(', ')}" unless failed.empty?

puts 'Core callback cleanup verified'
