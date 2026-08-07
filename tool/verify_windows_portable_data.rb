#!/usr/bin/env ruby
# frozen_string_literal: true

root = File.expand_path('..', __dir__)
read = ->(path) { File.read(File.join(root, path)) }

path_source = read.call('lib/common/path.dart')
path_test = read.call('test/common/path_test.dart')
workflow = read.call('.github/workflows/pull-request-validation.yaml')

checks = {
  'portable path is Windows-only and writable-directory gated' =>
    path_source.include?('String? resolvePortableDataRoot') &&
      path_source.include?('if (!isWindows || !appDirectoryWritable)') &&
      path_source.include?('Platform.isWindows && await _isDirectoryWritable'),
  'portable data and cache stay beside the executable' =>
    path_source.include?("join(executableDirectory, 'data')") &&
      path_source.include?("join(appDirPath, 'cache')"),
  'write probe is cleaned up and system directories remain the fallback' =>
    path_source.include?('await probe.delete()') &&
      path_source.include?('getApplicationSupportDirectory()') &&
      path_source.include?('getApplicationCacheDirectory()'),
  'path policy has focused tests' =>
    path_test.include?('uses executable directory when Windows directory is writable') &&
      path_test.include?('falls back when the executable directory is not writable') &&
      path_test.include?('does not change non-Windows data locations'),
  'Windows CI runs the focused path test' =>
    workflow.include?('windows-portable-data') &&
      workflow.include?('test/common/path_test.dart'),
}

failed = checks.each_with_object([]) do |(name, passed), names|
  names << name unless passed
end
abort "Windows portable data verifier failed: #{failed.join(', ')}" unless failed.empty?

puts 'Windows portable data wiring verified.'
