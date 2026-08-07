#!/usr/bin/env ruby

root = File.expand_path('..', __dir__)
state_path = File.join(
  root,
  'android',
  'app',
  'src',
  'main',
  'kotlin',
  'com',
  'follow',
  'clash',
  'State.kt',
)
vpn_service_path = File.join(
  root,
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
tile_manager_path = File.join(root, 'lib', 'manager', 'tile_manager.dart')
action_path = File.join(root, 'lib', 'providers', 'action.dart')

state = File.read(state_path)
vpn_service = File.read(vpn_service_path)
tile_manager = File.read(tile_manager_path)
action = File.read(action_path)

stop_action = state[/suspend fun handleStopServiceAction\(\).*?\n    \}\n\n    fun handleStartService/m]
abort 'Android stop action could not be located' unless stop_action

abort 'Android stop action does not notify the Flutter UI' unless
  stop_action.include?('tilePlugin?.handleStop()')

abort 'Android stop action still delegates the actual stop to Flutter state' if
  stop_action.match?(/tilePlugin\?\.handleStop\(\).*?if \(flutterEngine != null\).*?return/m)

abort 'Android stop action does not perform a native service stop' unless
  stop_action.include?('stopServiceLocked()')

abort 'Android VPN service does not clean up when the system revokes the VPN' unless
  vpn_service.match?(/override fun onRevoke\(\).*?Core\.stopTun\(\).*?stopSelf\(\)/m)

abort 'Android tile stop still depends on a possibly stale Flutter start state' if
  tile_manager.match?(/Future<void> onStop\(\).*?if \(!isStart\).*?return/m)

abort 'Android tile stop does not synchronize the native stop into Flutter state' unless
  tile_manager.match?(/Future<void> onStop\(\).*?syncStopped\(\)/m)

abort 'Flutter state does not expose the native stop synchronization path' unless
  action.include?('Future<void> syncStopped() async')

puts 'Android VPN stop cleanup verified'
