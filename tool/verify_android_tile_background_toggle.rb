#!/usr/bin/env ruby

root = File.expand_path('..', __dir__)
tile_service_path = File.join(
  root,
  'android',
  'app',
  'src',
  'main',
  'kotlin',
  'com',
  'follow',
  'clash',
  'TileService.kt',
)
tile_service = File.read(tile_service_path)

abort 'Android tile must toggle the service without launching an Activity' if
  tile_service.include?('startActivityAndCollapse') ||
  tile_service.include?('QuickAction.TOGGLE.quickIntent') ||
  tile_service.include?('toPendingIntent')

abort 'Android tile does not delegate its click to the background toggle state' unless
  tile_service.match?(/override fun onClick\(\).*?State\.handleToggleAction\(\)/m)

puts 'Android tile background toggle verified'
