# frozen_string_literal: true

common_source = File.read(File.expand_path('../core/common.go', __dir__))
constant_source = File.read(File.expand_path('../core/constant.go', __dir__))
state_source = File.read(File.expand_path('../lib/providers/state.dart', __dir__))
listener_test_source = File.read(
  File.expand_path('../core/update_config_listener_test.go', __dir__),
)

abort 'UpdateParams must expose the allow-lan update' unless
  constant_source.include?('AllowLan           *bool              `json:"allow-lan"`')

abort 'The Flutter update parameters must include the LAN proxy state' unless
  state_source.include?('allowLan: state.allowLan')

update_config = common_source.split(
  /func updateConfig\(params \*UpdateParams\)(?:\s+error)?\s*\{/,
  2,
).last
abort 'The core must apply allow-lan before recreating listeners' unless
  update_config&.include?('applyAllowLanUpdate(general, params.AllowLan)') &&
  update_config.index('applyAllowLanUpdate(general, params.AllowLan') <
    update_config.index('updateListeners()')

abort 'The allow-lan update helper must write the active general config' unless
  common_source.include?('general.AllowLan = *allowLan')

abort 'The runtime LAN regression test must exercise listener recreation' unless
  listener_test_source.include?('TestUpdateConfigRecreatesMixedListenerForAllowLan') &&
  listener_test_source.include?('updateConfig(&UpdateParams{AllowLan: &allowLan})') &&
  listener_test_source.include?('canConnectToAnyHost') &&
  listener_test_source.include?('previousAllowLan := listener.AllowLan()') &&
  listener_test_source.include?('previousBindAddress := listener.BindAddress()') &&
  listener_test_source.include?('LAN address remained reachable after allow-lan was disabled')

puts 'LAN proxy runtime update verified'
