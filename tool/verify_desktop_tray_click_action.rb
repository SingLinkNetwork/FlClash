#!/usr/bin/env ruby
# frozen_string_literal: true

root = File.expand_path('..', __dir__)
read = ->(path) { File.read(File.join(root, path)) }

enum = read.call('lib/enum/enum.dart')
model_map = read.call('lib/models/generated/config.g.dart')
tray = read.call('lib/common/tray.dart')
manager = read.call('lib/manager/tray_manager.dart')
view = read.call('lib/views/application_setting.dart')
tray_test = read.call('test/common/tray_test.dart')
model_test = read.call('test/models/config_test.dart')
view_test = read.call('test/views/application_setting_test.dart')

checks = {
  'desktop action exists and is serialized' =>
    enum.include?(
      'enum TrayClickAction { showMainWindow, showTrayMenu, toggleProxy }',
    ) &&
      model_map.include?("TrayClickAction.toggleProxy: 'toggleProxy'"),
  'left click invokes the existing proxy toggle pathway' =>
    tray.include?('case TrayClickAction.toggleProxy:') &&
      tray.include?('toggleProxy();') &&
      manager.include?('commonActionProvider.notifier).updateStart()'),
  'desktop settings expose the proxy toggle without exposing a tray menu' =>
    view.include?('if (system.isDesktop) const TrayClickActionItem()') &&
      view.include?('options: options') &&
      tray.include?('if (isMacOS) TrayClickAction.showTrayMenu'),
  'behavior, platform filtering, and persistence have focused tests' =>
    tray_test.include?('toggles the proxy when configured on a desktop platform') &&
      tray_test.include?('includes the tray menu only on macOS') &&
      model_test.include?('persists the desktop proxy toggle tray click action') &&
      view_test.include?('Start/stop proxy'),
  'all supported locales expose the proxy toggle label' =>
    Dir[File.join(root, 'arb', 'intl_*.arb')].all? do |path|
      File.read(path).include?('"trayClickAction_toggleProxy"')
    end,
}

failed = checks.each_with_object([]) do |(name, passed), names|
  names << name unless passed
end
abort "desktop tray click action verifier failed: #{failed.join(', ')}" unless failed.empty?

puts 'desktop tray proxy toggle wiring verified'
