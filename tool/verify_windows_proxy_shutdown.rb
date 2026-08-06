#!/usr/bin/env ruby

root = File.expand_path('..', __dir__)
runner_path = File.join(root, 'windows', 'runner', 'flutter_window.cpp')
header_path = File.join(root, 'plugins', 'proxy', 'windows', 'proxy_plugin.h')
plugin_path = File.join(root, 'plugins', 'proxy', 'windows', 'proxy_plugin.cpp')
c_api_header_path = File.join(
  root,
  'plugins',
  'proxy',
  'windows',
  'include',
  'proxy',
  'proxy_plugin_c_api.h',
)
c_api_source_path = File.join(
  root,
  'plugins',
  'proxy',
  'windows',
  'proxy_plugin_c_api.cpp',
)

runner = File.read(runner_path)
header = File.read(header_path)
plugin = File.read(plugin_path)
c_api_header = File.read(c_api_header_path)
c_api_source = File.read(c_api_source_path)

abort 'Windows Runner does not include the proxy C API shutdown bridge' unless
  runner.include?('#include "proxy/proxy_plugin_c_api.h"')

abort 'Windows Runner does not clean the proxy on WM_ENDSESSION' unless
  runner.match?(/if \(message == WM_ENDSESSION && wparam != 0\).*?ProxyPluginStopForSessionEnd\(\);/m)

abort 'proxy plugin does not expose the session-end cleanup bridge' unless
  header.include?('void stopProxyForSessionEnd();')

abort 'proxy plugin does not route session-end cleanup to stopProxy' unless
  plugin.match?(/void stopProxyForSessionEnd\(\)\s*\{\s*stopProxy\(\);\s*\}/m)

abort 'proxy C API does not export the session-end cleanup bridge' unless
  c_api_header.include?(
    'FLUTTER_PLUGIN_EXPORT void ProxyPluginStopForSessionEnd();',
  )

abort 'proxy C API does not forward session-end cleanup to the plugin' unless
  c_api_source.match?(
    /void ProxyPluginStopForSessionEnd\(\)\s*\{\s*proxy::stopProxyForSessionEnd\(\);\s*\}/m,
  )

puts 'Windows proxy cleanup on WM_ENDSESSION verified'
