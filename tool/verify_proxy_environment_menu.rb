#!/usr/bin/env ruby

root = File.expand_path('..', __dir__)
environment_source = File.read(
  File.join(root, 'lib', 'common', 'proxy_environment.dart'),
)
tray_source = File.read(File.join(root, 'lib', 'common', 'tray.dart'))
test_source = File.read(
  File.join(root, 'test', 'common', 'proxy_environment_test.dart'),
)
tray_test_source = File.read(File.join(root, 'test', 'common', 'tray_test.dart'))
workflow_source = File.read(
  File.join(root, '.github', 'workflows', 'pull-request-validation.yaml'),
)

%w[bash fish zsh powershell].each do |shell|
  abort "Shell enum is missing: #{shell}" unless
    environment_source.include?("ProxyEnvironmentShell.#{shell}")
end

[
  'export all_proxy=$url',
  'set -gx all_proxy $url',
  %q{'\$env:all_proxy},
  'buildProxyEnvironmentShellCommand',
].each do |fragment|
  abort "Proxy environment command wiring is missing: #{fragment}" unless
    environment_source.include?(fragment)
end

[
  'MenuItem.submenu',
  'buildProxyEnvironmentMenuItems',
  'buildProxyEnvironmentShellCommand',
  'ProxyEnvironmentShell.values',
].each do |fragment|
  abort "Tray shell submenu wiring is missing: #{fragment}" unless
    tray_source.include?(fragment)
end

abort 'Proxy environment focused tests are missing' unless
  test_source.include?('ProxyEnvironmentShell.powershell') &&
  tray_test_source.include?('buildProxyEnvironmentMenuItems')
abort 'Proxy environment CI job is missing' unless
  workflow_source.include?('proxy-environment:') &&
  workflow_source.include?(
    'flutter test test/common/proxy_environment_test.dart test/common/tray_test.dart --reporter expanded',
  )
abort 'Proxy environment static CI check is missing' unless
  workflow_source.include?('id: proxy-environment-menu') &&
  workflow_source.include?('script: tool/verify_proxy_environment_menu.rb')

puts 'Proxy environment menu wiring verified'
