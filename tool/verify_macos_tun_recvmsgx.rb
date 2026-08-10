#!/usr/bin/env ruby

root = File.expand_path('..', __dir__)
model = File.read(File.join(root, 'lib', 'models', 'clash_config.dart'))
task = File.read(File.join(root, 'lib', 'common', 'task.dart'))
network = File.read(File.join(root, 'lib', 'views', 'config', 'network.dart'))
test = File.read(File.join(root, 'test', 'models', 'config_test.dart'))
task_test = File.read(File.join(root, 'test', 'common', 'task_test.dart'))
core_constants = File.read(File.join(root, 'core', 'constant.go'))
core_common = File.read(File.join(root, 'core', 'common.go'))
core_test = File.read(File.join(root, 'core', 'update_config_listener_test.go'))

abort 'TUN model must default recvmsgx to enabled and use the core key' unless
  model.match?(
    /@JsonKey\(name: 'recvmsgx'\)\s+@Default\(true\) bool recvMsgX/,
  )

abort 'macOS profile generation must write the recvmsgx setting' unless
  task.match?(
    /if \(Platform\.isMacOS\)\s*\{\s*rawConfig\['tun'\]\['recvmsgx'\]\s*=\s*realPatchConfig\.tun\.recvMsgX;/m,
  )

abort 'core update parameters must carry recvmsgx' unless
  core_constants.match?(/RecvMsgX\s+\*bool\s+`yaml:"recvmsgx" json:"recvmsgx,omitempty"`/)

abort 'core updateConfig must apply recvmsgx and recreate listeners' unless
  core_common.match?(/params\.Tun\.RecvMsgX != nil/) &&
  core_common.match?(/general\.Tun\.RecvMsgX = \*params\.Tun\.RecvMsgX/) &&
  core_common.include?('updateListeners()')

abort 'recvmsgx UI must be implemented as a dedicated setting item' unless
  network.include?('class TunRecvMsgXItem') &&
  network.include?('state.tun.recvMsgX') &&
  network.include?('copyWith.tun(recvMsgX: value)')

abort 'recvmsgx UI must only be exposed on macOS' unless
  network.match?(/if \(system\.isMacOS\) const TunRecvMsgXItem\(\)/)

abort 'recvmsgx needs focused serialization tests' unless
  test.include?('Tun recvmsgx JSON') &&
  test.include?('recvMsgX: false') &&
  test.include?("'recvmsgx': false")

abort 'recvmsgx needs a focused profile-output test' unless
  task_test.include?('profile output writes recvmsgx only for macOS') &&
  task_test.include?("contains('recvmsgx: false')")

abort 'recvmsgx needs a focused core update test' unless
  core_test.include?('TestUpdateConfigAppliesRecvMsgX') &&
  core_test.include?('RecvMsgX: &recvMsgX')

puts 'macOS TUN recvmsgx wiring verified'
