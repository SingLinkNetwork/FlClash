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
plugin_cmake_path = File.join(root, 'plugins', 'proxy', 'windows', 'CMakeLists.txt')
platform_interface_path = File.join(root, 'plugins', 'proxy', 'lib', 'proxy_platform_interface.dart')
method_channel_path = File.join(root, 'plugins', 'proxy', 'lib', 'proxy_method_channel.dart')
proxy_path = File.join(root, 'plugins', 'proxy', 'lib', 'proxy.dart')
controller_path = File.join(root, 'lib', 'core', 'controller.dart')

runner = File.read(runner_path)
header = File.read(header_path)
plugin = File.read(plugin_path)
c_api_header = File.read(c_api_header_path)
c_api_source = File.read(c_api_source_path)
plugin_cmake = File.read(plugin_cmake_path)
platform_interface = File.read(platform_interface_path)
method_channel = File.read(method_channel_path)
proxy = File.read(proxy_path)
controller = File.read(controller_path)

abort 'Windows Runner does not include the proxy C API cleanup bridge' unless
  runner.include?('#include "proxy/proxy_plugin_c_api.h"')

abort 'Windows Runner does not reset the TUN metric on WM_ENDSESSION' unless
  runner.match?(/if \(message == WM_ENDSESSION && wparam != 0\).*?ProxyPluginResetTunInterface\(\);/m)

abort 'proxy plugin does not expose TUN metric cleanup' unless
  header.include?('bool resetTunInterface();')

%w[
  GetAdaptersAddresses
  GetIpForwardTable2
  DeleteIpForwardEntry2
  GetIpInterfaceEntry
  SetIpInterfaceEntry
].each do |api|
  abort "proxy plugin does not call #{api} for TUN cleanup" unless plugin.include?(api)
end

abort 'proxy plugin does not restore automatic interface metrics' unless
  plugin.include?('UseAutomaticMetric = TRUE')

abort 'proxy plugin does not scope cleanup to the FlClash adapter' unless
  plugin.include?('FlClash') && plugin.include?('FriendlyName')

abort 'proxy plugin does not include Winsock before Windows networking APIs' unless
  plugin.include?('#include <winsock2.h>') && plugin.include?('#include <ws2ipdef.h>')

abort 'proxy plugin does not expose the method-channel cleanup method' unless
  plugin.include?('ResetTunInterface')

abort 'proxy C API does not export the TUN metric cleanup bridge' unless
  c_api_header.include?('FLUTTER_PLUGIN_EXPORT void ProxyPluginResetTunInterface();')

abort 'proxy C API does not forward TUN metric cleanup to the plugin' unless
  c_api_source.match?(
    /void ProxyPluginResetTunInterface\(\)\s*\{\s*proxy::resetTunInterface\(\);\s*\}/m,
  )

abort 'Windows proxy plugin is not linked with iphlpapi' unless
  plugin_cmake.include?('wininet rasapi32 iphlpapi')

abort 'Windows proxy plugin is not linked with Winsock' unless
  plugin_cmake.include?('ws2_32')

abort 'Dart proxy platform does not expose TUN metric cleanup' unless
  platform_interface.include?('Future<bool?> resetTunInterface()')

abort 'Dart method channel does not invoke TUN metric cleanup' unless
  method_channel.match?(/resetTunInterface\(\).*?ResetTunInterface/m)

abort 'Dart proxy facade does not dispatch Windows TUN metric cleanup' unless
  proxy.match?(/Future<bool\?> resetTunInterface\(\).*?'windows'.*?ProxyPlatform\.instance\.resetTunInterface/m)

abort 'core shutdown does not request Windows TUN metric cleanup' unless
  controller.include?('proxy?.resetTunInterface()')

puts 'Windows TUN route and metric cleanup verified'
