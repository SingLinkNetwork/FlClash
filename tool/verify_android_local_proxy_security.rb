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
core_patch = read.call(
  'tool',
  'patches',
  '0001-android-disable-default-udp-listeners.patch',
)
patch_applier = read.call('tool', 'apply_clash_meta_patches.dart')
dart_test = File.join(root, 'test', 'common', 'local_proxy_test.dart')
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
    http.include?('shouldAuthenticateLocalProxy')

abort 'Dart proxy authentication helper does not restrict local Basic challenges' unless
  local_proxy.include?('bool shouldAuthenticateLocalProxy') &&
    local_proxy.include?("host == 'localhost'") &&
    local_proxy.include?("host == '127.0.0.1'") &&
    local_proxy.include?("scheme.toLowerCase() == 'basic'")

abort 'Android shared VPN state can still request the system proxy' unless
  state.include?('shouldUseSystemProxy') &&
    state.match?(/systemProxy: shouldUseSystemProxy\(/)

abort 'Android UI still exposes the unsupported VPN system proxy switch' if
  network.include?('VpnSystemProxyItem') || quick_options.include?('VpnSystemProxyItem')

abort 'Android service still creates an unauthenticated system HTTP proxy' if
  vpn_service.include?('ProxyInfo') || vpn_service.include?('setHttpProxy')

abort 'Core patch does not gate default UDP on Android' unless
  core_patch.include?('shouldDisableDefaultUDP') &&
    core_patch.include?('features.Android') &&
    core_patch.scan('disableUDP := defaultUDPDisabled()').length == 2 &&
    core_patch.include?('if disableUDP || socksUDPListener.RawAddress() != addr') &&
    core_patch.include?('if disableUDP || mixedUDPLister.RawAddress() != addr') &&
    core_patch.scan('if disableUDP || shouldUDPIgnore').length == 2

abort 'Dart local proxy regression test is missing' unless File.file?(dart_test)
abort 'Dart local proxy authentication regression test is missing' unless
  File.read(dart_test).include?(
    'Android proxy authentication only accepts a local Basic challenge',
  )

abort 'Core patch does not contain the Go local proxy regression test' unless
  core_patch.include?('listener_security_test.go') &&
  core_patch.include?('TestShouldDisableDefaultUDP')

abort 'Core patch applier is missing' unless
  patch_applier.include?('applyClashMetaPatches')

abort 'Android local proxy security verifier is not wired into CI' unless
  workflow.include?('script: tool/verify_android_local_proxy_security.rb') &&
    workflow.include?("go test ./listener -run '^TestShouldDisableDefaultUDP$' -count=1")

puts 'Android local proxy security wiring verified'
