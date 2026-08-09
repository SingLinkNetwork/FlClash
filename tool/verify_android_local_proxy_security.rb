#!/usr/bin/env ruby

root = File.expand_path('..', __dir__)
read = ->(*parts) { File.read(File.join(root, *parts)) }

local_proxy = read.call('lib', 'common', 'local_proxy.dart')
http = read.call('lib', 'common', 'http.dart')
action = read.call('lib', 'providers', 'action.dart')
state = read.call('lib', 'providers', 'state.dart')
network = read.call('lib', 'views', 'config', 'network.dart')
quick_options = read.call('lib', 'views', 'dashboard', 'widgets', 'quick_options.dart')
vpn_service = read.call(
  'android',
  'service',
  'src',
  'main',
  'java',
  'com',
  'follow',
  'clash',
  'service',
  'VpnService.kt',
)
listener = read.call('core', 'Clash.Meta', 'listener', 'listener.go')
dart_test = File.join(root, 'test', 'common', 'local_proxy_test.dart')
go_test = File.join(
  root,
  'core',
  'Clash.Meta',
  'listener',
  'listener_security_test.go',
)
workflow = read.call('.github', 'workflows', 'pull-request-validation.yaml')

abort 'Android local proxy helper is missing secure random credentials' unless
  local_proxy.include?('Random.secure()') &&
    local_proxy.include?('coreAuthentication')

abort 'Android profile generation does not replace authentication' unless
  action.match?(/if \(system\.isAndroid\).*?applyAndroidLocalProxyAuthentication/m) &&
    action.include?('globalState.localProxyCredentials')

abort 'Dart proxy client does not handle authenticated local proxy challenges' unless
  http.include?('authenticateProxy') &&
    http.include?('addProxyCredentials') &&
    http.include?('HttpClientBasicCredentials') &&
    http.include?('isLocalProxyEndpoint')

abort 'Android shared VPN state can still request the system proxy' unless
  state.include?('shouldUseSystemProxy') &&
    state.match?(/systemProxy: shouldUseSystemProxy\(/)

abort 'Android UI still exposes the unsupported VPN system proxy switch' if
  network.include?('VpnSystemProxyItem') || quick_options.include?('VpnSystemProxyItem')

abort 'Android service still creates an unauthenticated system HTTP proxy' if
  vpn_service.include?('ProxyInfo') || vpn_service.include?('setHttpProxy')

abort 'Core does not gate default UDP on Android authentication' unless
  listener.include?('shouldDisableDefaultUDP') &&
    listener.include?('features.Android') &&
    listener.scan('socks.NewUDP').length == 2 &&
    listener.scan('if disableUDP || shouldUDPIgnore').length == 2

abort 'Dart local proxy regression test is missing' unless File.file?(dart_test)
abort 'Go local proxy regression test is missing' unless File.file?(go_test)

abort 'Android local proxy security verifier is not wired into CI' unless
  workflow.include?('script: tool/verify_android_local_proxy_security.rb')

puts 'Android local proxy security wiring verified'
