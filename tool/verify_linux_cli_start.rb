#!/usr/bin/env ruby

root = File.expand_path('..', __dir__)
main_source = File.read(File.join(root, 'lib', 'main.dart'))
startup_source = File.read(File.join(root, 'lib', 'common', 'startup.dart'))
state_source = File.read(File.join(root, 'lib', 'state.dart'))
action_source = File.read(File.join(root, 'lib', 'providers', 'action.dart'))
test_source = File.read(File.join(root, 'test', 'common', 'startup_test.dart'))

abort 'Linux CLI start must receive Dart entrypoint arguments' unless
  main_source.match?(/Future<void> main\(List<String> arguments\)/)
abort 'Linux CLI start must be restricted to Linux' unless
  main_source.match?(/Platform\.isLinux\s*&&\s*shouldStartProxyFromArguments\(arguments\)/)
abort 'Linux CLI start must use the documented --start argument' unless
  startup_source.match?(/startProxyArgument\s*=\s*['"]--start['"]/) &&
  startup_source.match?(/arguments\.contains\(startProxyArgument\)/)
abort 'Linux CLI start must force the existing startup status path' unless
  state_source.match?(/initStatus\(\s*\n?\s*forceStart:\s*startProxyFromCommandLine/m) &&
  action_source.match?(/Future<void> initStatus\(\{bool forceStart = false\}\)/) &&
  action_source.match?(/forceStart\s*\|\|\s*isStart == true/)
abort 'Linux CLI start must have focused argument tests' unless
  test_source.include?('shouldStartProxyFromArguments') &&
  test_source.include?("['--start']")

puts 'Linux CLI start verified'
