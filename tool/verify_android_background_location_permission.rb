#!/usr/bin/env ruby

manifest = File.read(
  File.expand_path('../android/app/src/main/AndroidManifest.xml', __dir__),
)

required_permission =
  '<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"'

abort 'Android manifest is missing ACCESS_BACKGROUND_LOCATION' unless
  manifest.include?(required_permission)

puts 'Android background location permission declaration verified'
