#!/usr/bin/env ruby
# frozen_string_literal: true

root = File.expand_path('..', __dir__)
action_source = File.read(
  File.join(root, 'lib', 'providers', 'action.dart'),
)
window_manager_source = File.read(
  File.join(root, 'lib', 'manager', 'window_manager.dart'),
)

checks = {
  'desktop close uses the desktop-aware handler' =>
    action_source.include?('Future<void> handleClose([bool exit = true])') &&
      !action_source.include?('handleBackOrExit'),
  'mobile back blocking does not block desktop window close' =>
    action_source.match?(
      /if \(!system\.isDesktop\)\s*\{\s*if \(ref\.read\(backBlockProvider\)\) return;/m,
    ),
  'native window close calls the fixed handler' =>
    window_manager_source.match?(
      /void onWindowClose\(\) async \{.*?handleClose\(\);/m,
    ),
  'custom desktop close button calls the fixed handler' =>
    window_manager_source.scan('handleClose();').length >= 2,
}

failed = checks.each_with_object([]) do |(name, passed), names|
  names << name unless passed
end
abort "Windows search close verifier failed: #{failed.join(', ')}" unless
  failed.empty?

puts 'Windows search close verifier: PASS'
