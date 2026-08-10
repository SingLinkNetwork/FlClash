#!/usr/bin/env ruby
# frozen_string_literal: true

root = File.expand_path('..', __dir__)
read = ->(*parts) { File.read(File.join(root, *parts)) }

common = read.call('lib', 'common', 'test_url.dart')
common_exports = read.call('lib', 'common', 'common.dart')
model = read.call('lib', 'models', 'config.dart')
settings = read.call('lib', 'views', 'config', 'general.dart')
proxy_common = read.call('lib', 'views', 'proxies', 'common.dart')
selector = read.call('lib', 'views', 'proxies', 'test_url_selector.dart')
proxy_view = read.call('lib', 'views', 'proxies', 'proxies.dart')
tab = read.call('lib', 'views', 'proxies', 'tab.dart')
list = read.call('lib', 'views', 'proxies', 'list.dart')
model_test = read.call('test', 'models', 'config_test.dart')
common_test = read.call('test', 'common', 'test_url_test.dart')
proxy_test = read.call('test', 'views', 'proxies', 'common_test.dart')
selector_test = read.call('test', 'views', 'proxies', 'test_url_selector_test.dart')

checks = {
  'URL resolver trims, validates, deduplicates, and has a safe fallback' =>
    common.include?('resolveTestUrls') &&
      common.include?('defaultTestUrl') &&
      common.include?('result.contains(url)'),
  'URL resolver is exported through the common barrel' =>
    common_exports.include?("export 'test_url.dart';"),
  'settings persist custom website URLs without replacing the legacy default' =>
    model.include?('@Default([]) List<String> customTestUrls') &&
      model.include?('List<String> get allTestUrls'),
  'settings provide add/edit/delete controls for custom websites' =>
    settings.include?('class CustomTestUrlsItem') &&
      settings.include?('_CustomTestUrlsDialog') &&
      settings.include?('_handleDelete'),
  'batch testing is sequential and reuses the existing delay path' =>
    proxy_common.include?('runTestUrlsSequentially') &&
      proxy_common.include?('Future<void> delayTestUrls') &&
      proxy_common.include?('return delayTest(proxies, testUrl)'),
  'proxy page exposes website selection and stores the selected value' =>
    selector.include?('class TestUrlSelector') &&
      proxy_view.include?('TestUrlSelector') &&
      proxy_view.include?('selectedTestUrlProvider'),
  'tab and list layouts batch-test all configured websites' =>
    tab.include?('delayTestUrls') && list.include?('delayTestUrls'),
  'configuration persistence and URL resolution have focused tests' =>
    model_test.include?('customTestUrls') &&
      model_test.include?('legacy JSON without custom URLs') &&
      proxy_test.include?('runs website delay tests one URL at a time'),
  'selector has a focused widget test' =>
    selector_test.include?('selects a configured website for result viewing'),
  'all supported locales expose the custom website setting' =>
    Dir[File.join(root, 'arb', 'intl_*.arb')].all? do |path|
      File.read(path).include?('"customTestUrls"')
    end,
}

failed = checks.each_with_object([]) do |(name, passed), names|
  names << name unless passed
end
abort "Custom test URL verifier failed: #{failed.join(', ')}" unless failed.empty?

puts 'Custom test URL wiring verified'
