#!/usr/bin/env ruby
# frozen_string_literal: true

root = File.expand_path('..', __dir__)

read = lambda do |relative_path|
  File.read(File.join(root, relative_path))
end

core_forwarding = read.call('core/ip_forwarding.go')
core_action = read.call('core/action.go')
core_constants = read.call('core/constant.go')
interface = read.call('lib/core/interface.dart')
controller = read.call('lib/core/controller.dart')
enum = read.call('lib/enum/enum.dart')
model = read.call('lib/models/config.dart')
network = read.call('lib/views/config/network.dart')
state = read.call('lib/providers/state.dart')
action = read.call('lib/providers/action.dart')
manager = read.call('lib/manager/app_manager.dart')
core_manager = read.call('lib/manager/core_manager.dart')

checks = {
  'core uses the fixed macOS sysctl key' =>
    core_forwarding.include?('net.inet.ip.forwarding'),
  'core keeps macOS-only behavior and restores the original value' =>
    core_forwarding.include?('ipForwardingPlatform != "darwin"') &&
      core_forwarding.include?('ipForwardingOriginal') &&
      core_forwarding.include?('resetIPForwardingState'),
  'core dispatches the forwarding action' =>
    core_constants.include?('setIPForwardingMethod') &&
      core_action.include?('case setIPForwardingMethod') &&
      core_action.include?('action.Data.(bool)'),
  'Dart IPC exposes the forwarding action' =>
    enum.include?('setIpForwarding') &&
      interface.include?('Future<bool> setIpForwarding(bool enabled)') &&
      controller.include?('setIpForwarding(bool enabled)'),
  'setting defaults to disabled' =>
    model.match?(/@Default\(false\) bool macOSIpForwarding/),
  'macOS-only setting is visible in the network page' =>
    network.include?('class MacOSIpForwardingItem') &&
      network.include?('if (system.isMacOS) const MacOSIpForwardingItem()'),
  'runtime eligibility checks every required condition' =>
    state.include?('isMacOSIpForwardingEligible') &&
      state.include?('configured:') &&
      state.include?('tunEnabled:') &&
      state.include?('isStarted:') &&
      state.include?('coreConnected:'),
  'runtime changes are serialized and restored before restart and exit' =>
    action.include?('IpForwardingRequestQueue') &&
      action.include?('await setIpForwarding(false)') &&
      manager.include?('shouldEnableMacOSIpForwardingProvider') &&
      core_manager.include?('await ref.read(coreActionProvider.notifier).setIpForwarding(false)'),
  'focused regression tests exist' =>
    File.file?(File.join(root, 'core/ip_forwarding_test.go')) &&
      File.file?(File.join(root, 'test/core/ip_forwarding_action_test.dart')) &&
      File.file?(File.join(root, 'test/models/macos_ip_forwarding_test.dart')) &&
      File.file?(File.join(root, 'test/providers/ip_forwarding_state_test.dart')) &&
      File.file?(File.join(root, 'test/views/config/network_test.dart')),
}

failed = checks.each_with_object([]) do |(name, passed), names|
  names << name unless passed
end
abort "macOS IP forwarding verifier failed: #{failed.join(', ')}" unless failed.empty?

puts 'macOS IP forwarding wiring and regression tests verified'
