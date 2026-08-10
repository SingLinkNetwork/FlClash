#!/usr/bin/env ruby

source_path = ARGV.fetch(0, 'plugins/wifi_ssid/windows/wifi_ssid_plugin.cpp')
cmake_path = ARGV.fetch(1, 'plugins/wifi_ssid/windows/CMakeLists.txt')

source = File.read(source_path)
cmake = File.read(cmake_path)
errors = []

if source.include?('#pragma comment(lib, "wlanapi.lib")')
  errors << 'Windows Wi-Fi SSID source must not statically import wlanapi.lib'
end

if cmake.match?(/target_link_libraries\([^)]*\bwlanapi\b/m)
  errors << 'Windows Wi-Fi SSID CMake target must not link wlanapi.lib statically'
end

unless source.include?('LoadLibraryW(L"wlanapi.dll")')
  errors << 'Windows Wi-Fi SSID source must load wlanapi.dll at runtime'
end

unless source.include?('GetProcAddress')
  errors << 'Windows Wi-Fi SSID source must resolve WLAN functions dynamically'
end

%w[
  WlanOpenHandle
  WlanEnumInterfaces
  WlanQueryInterface
  WlanFreeMemory
  WlanCloseHandle
].each do |function_name|
  unless source.include?(function_name)
    errors << "Windows Wi-Fi SSID source must preserve #{function_name}"
  end
end

unless source.include?('FreeLibrary')
  errors << 'Windows Wi-Fi SSID source must release the optional WLAN library'
end

if errors.empty?
  puts 'Windows Wi-Fi SSID optional dependency verifier passed.'
  exit 0
end

warn errors.map { |error| "ERROR: #{error}" }
exit 1
