#!/usr/bin/env ruby

source_path = File.expand_path(
  '../plugins/wifi_ssid/macos/wifi_ssid/Sources/wifi_ssid/WifiSsidPlugin.swift',
  __dir__,
)
source = File.read(source_path)

required_fragments = [
  'locationManager.authorizationStatus == .authorizedAlways',
  'DispatchQueue.global(qos: .utility).async',
  'DispatchQueue.main.async',
]
required_fragments.each do |fragment|
  abort "macOS Wi-Fi SSID plugin is missing: #{fragment}" unless source.include?(fragment)
end

abort 'macOS Wi-Fi SSID plugin still reads CoreWLAN synchronously' if
  source.include?('result(interface.ssid())')

puts 'macOS Wi-Fi SSID permission guard and background read verified'
