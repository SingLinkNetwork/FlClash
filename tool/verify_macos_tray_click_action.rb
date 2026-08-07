#!/usr/bin/env ruby
# frozen_string_literal: true

root = File.expand_path('..', __dir__)
read = ->(path) { File.read(File.join(root, path)) }

enum = read.call('lib/enum/enum.dart')
model = read.call('lib/models/config.dart')
tray = read.call('lib/common/tray.dart')
manager = read.call('lib/manager/tray_manager.dart')
view = read.call('lib/views/application_setting.dart')
tray_test = read.call('test/common/tray_test.dart')
model_test = read.call('test/models/config_test.dart')
view_test = read.call('test/views/application_setting_test.dart')

checks = {
  'tray click action keeps the supported choices' =>
    enum.include?(
      'enum TrayClickAction { showMainWindow, showTrayMenu, toggleProxy }',
    ),
  'old settings keep showing the main window' =>
    model.include?('@Default(TrayClickAction.showMainWindow) TrayClickAction trayClickAction'),
  'macOS uses the saved action while other platforms keep the main window' =>
    tray.include?('return isMacOS ? showMenu() : showWindow();') &&
      manager.include?('isMacOS: system.isMacOS') &&
      manager.include?('action: ref.read(appSettingProvider).trayClickAction'),
  'tray manager can open the menu on a left click' =>
    manager.include?('trayManager.popUpContextMenu(bringAppToFront: true)'),
  'settings expose the desktop choices and filter the macOS menu' =>
    view.include?('if (system.isDesktop) const TrayClickActionItem()') &&
      view.include?('supportedTrayClickActions(isMacOS: system.isMacOS)'),
  'behavior and persistence have focused tests' =>
    tray_test.include?('handleTrayIconMouseDown') &&
      model_test.include?('persists the macOS tray click action') &&
      view_test.include?('tray click action is visible and persists a new selection'),
  'all supported locales expose the choice labels' =>
    Dir[File.join(root, 'arb', 'intl_*.arb')].all? do |path|
      content = File.read(path)
      content.include?('"trayClickAction"') &&
        content.include?('"trayClickAction_showMainWindow"') &&
        content.include?('"trayClickAction_showTrayMenu"') &&
        content.include?('"trayClickAction_toggleProxy"')
    end,
}

failed = checks.each_with_object([]) do |(name, passed), names|
  names << name unless passed
end
abort "macOS tray click action verifier failed: #{failed.join(', ')}" unless failed.empty?

puts 'desktop tray click action wiring verified'
