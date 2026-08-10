# frozen_string_literal: true

source = File.read(
  File.expand_path('../lib/common/tray.dart', __dir__),
)

destroy_body = source[/Future<void> destroy\(\) async \{(.*?)\n  \}/m, 1]
abort 'Tray.destroy implementation is missing' unless destroy_body

guard = 'shouldDestroyTrayOnExit(isMacOS: system.isMacOS)'
tray_destroy = 'trayManager.destroy()'
abort 'Tray.destroy must guard macOS before destroying the status item' unless
  destroy_body.include?(guard) &&
  destroy_body.index(guard) < destroy_body.index(tray_destroy)

abort 'macOS tray guard must keep non-macOS destroy behavior' unless
  source.include?('bool shouldDestroyTrayOnExit({required bool isMacOS}) => !isMacOS;')

puts 'macOS tray destroy guard verified'
