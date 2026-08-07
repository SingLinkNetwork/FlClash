# frozen_string_literal: true

common_source = File.read(File.expand_path('../core/common.go', __dir__))
constant_source = File.read(File.expand_path('../core/constant.go', __dir__))
state_source = File.read(File.expand_path('../lib/providers/state.dart', __dir__))

abort 'UpdateParams must expose the allow-lan update' unless
  constant_source.include?('AllowLan           *bool              `json:"allow-lan"`')

abort 'The Flutter update parameters must include the LAN proxy state' unless
  state_source.include?('allowLan: state.allowLan')

update_config = common_source.split('func updateConfig(params *UpdateParams) {', 2).last
abort 'The core must apply allow-lan before recreating listeners' unless
  update_config&.include?('applyAllowLanUpdate(general, params.AllowLan)') &&
  update_config.index('applyAllowLanUpdate(general, params.AllowLan') <
    update_config.index('updateListeners()')

abort 'The allow-lan update helper must write the active general config' unless
  common_source.include?('general.AllowLan = *allowLan')

puts 'LAN proxy runtime update verified'
