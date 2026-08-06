#!/usr/bin/env ruby

require 'json'
require 'uri'
require 'yaml'

root = File.expand_path('..', __dir__)
pubspec = YAML.load_file(File.join(root, 'pubspec.yaml'))
lockfile = YAML.load_file(File.join(root, 'pubspec.lock'))

git_config = pubspec.fetch('dependencies').fetch('tray_manager').fetch('git')
ref = git_config.fetch('ref').to_s
unless ref.match?(/\A[0-9a-f]{40}\z/)
  abort 'tray_manager must be pinned to a 40-character commit SHA'
end

resolved_ref = lockfile.fetch('packages').fetch('tray_manager').fetch('description').fetch('resolved-ref')
unless resolved_ref == ref
  abort "pubspec.lock resolves tray_manager to #{resolved_ref}, expected #{ref}"
end

package_config_path = File.join(root, '.dart_tool', 'package_config.json')
package_config = JSON.parse(File.read(package_config_path))
package = package_config.fetch('packages').find { |item| item['name'] == 'tray_manager' }
abort 'tray_manager is missing from .dart_tool/package_config.json' unless package

package_root = URI.parse(package.fetch('rootUri')).path
source_path = File.join(package_root, 'macos', 'tray_manager', 'Classes', 'TrayIcon.swift')
source = File.read(source_path)

abort 'tray_manager macOS source does not use SpeedTextView' unless source.include?('class SpeedTextView: NSView')
abort 'tray_manager macOS source still uses NSTextField' if source.include?('NSTextField')

puts "tray_manager #{ref}: pinned and self-drawn macOS title view verified"
