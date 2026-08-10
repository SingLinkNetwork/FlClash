#!/usr/bin/env ruby

root = File.expand_path('..', __dir__)
remote_service_path = File.join(
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
  'RemoteService.kt',
)
manifest_path = File.join(root, 'android', 'service', 'src', 'main', 'AndroidManifest.xml')

remote_service = File.read(remote_service_path)
manifest = File.read(manifest_path)

abort 'Android remote service must start the managed service as a foreground service on Android O+' unless
  remote_service.match?(
    /Build\.VERSION\.SDK_INT\s*>=\s*Build\.VERSION_CODES\.O.*?startForegroundService\(serviceIntent\)/m,
  )

abort 'Android remote service must keep the pre-O service start fallback' unless
  remote_service.include?('startService(serviceIntent)')

start_call = remote_service.index('startManagedService(nextIntent)')
bind_call = remote_service.index('delegate?.bind()')
abort 'Android managed service must be started before the binder is attached' unless
  start_call && bind_call && start_call < bind_call

abort 'Android remote service must explicitly stop the managed service' unless
  remote_service.include?('stopManagedService(currentIntent)') &&
    remote_service.include?('GlobalState.application.stopService(serviceIntent)')

abort 'Android VPN service must remain a foreground service' unless
  manifest.match?(
    /android:name="\.VpnService".*?android:foregroundServiceType="specialUse"/m,
  )

abort 'Android proxy service must remain a foreground service' unless
  manifest.match?(
    /android:name="\.CommonService".*?android:foregroundServiceType="specialUse"/m,
  )

puts 'Android foreground service lifecycle verified'
