#!/usr/bin/env ruby
# frozen_string_literal: true

root = File.expand_path('..', __dir__)
main = File.read(File.join(root, 'lib', 'main.dart'))
implementation = File.read(File.join(root, 'lib', 'common', 'windows_paste.dart'))
test = File.read(File.join(root, 'test', 'common', 'windows_paste_test.dart'))

checks = {
  'main enables the fix only on Windows' =>
    main.include?('if (Platform.isWindows)') &&
      main.include?('WindowsPasteFix.instance.install()'),
  'fix wraps Flutter key data callback' =>
    implementation.include?('dispatcher.onKeyData') &&
      implementation.include?('WindowsPasteKeyNormalizer'),
  'fix identifies the malformed clipboard sequence' =>
    implementation.include?('malformedPhysicalKey') &&
      implementation.include?('LogicalKeyboardKey.controlLeft') &&
      implementation.include?('LogicalKeyboardKey.keyV') &&
      implementation.include?('!data.synthesized'),
  'fix releases incomplete sequences' =>
    implementation.include?('hasPendingSequence') &&
      implementation.include?('sequenceTimeout') &&
      implementation.include?('flush()'),
  'state-machine regression tests exist' =>
    test.include?('rewrites the malformed Windows clipboard history sequence') &&
      test.include?('replays an incomplete sequence'),
}

failed = checks.each_with_object([]) do |(name, passed), names|
  names << name unless passed
end
abort "Windows paste verifier failed: #{failed.join(', ')}" unless failed.empty?

puts 'Windows Win+V paste verifier: PASS'
