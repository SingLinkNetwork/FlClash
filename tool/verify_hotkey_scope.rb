#!/usr/bin/env ruby
# frozen_string_literal: true

root = File.expand_path('..', __dir__)
enum = File.read(File.join(root, 'lib', 'enum', 'enum.dart'))
model = File.read(File.join(root, 'lib', 'models', 'common.dart'))
manager = File.read(File.join(root, 'lib', 'manager', 'hotkey_manager.dart'))
view = File.read(File.join(root, 'lib', 'views', 'hotkey.dart'))
test = File.read(File.join(root, 'test', 'models', 'config_test.dart'))
enum_test = File.read(File.join(root, 'test', 'enum', 'enum_test.dart'))
pubspec = File.read(File.join(root, 'pubspec.yaml'))

checks = {
  'hotkey manager package is available' => pubspec.include?('hotkey_manager: ^0.2.3'),
  'trigger scope has global and in-app values' =>
    enum.include?('enum HotKeyTriggerScope { global, inApp }'),
  'trigger scope maps to system and in-app plugin scopes' =>
    enum.include?('HotKeyTriggerScope.global => HotKeyScope.system') &&
      enum.include?('HotKeyTriggerScope.inApp => HotKeyScope.inapp'),
  'hotkey model defaults to global for old settings' =>
    model.include?('@Default(HotKeyTriggerScope.global) HotKeyTriggerScope scope'),
  'hotkey registration uses the saved scope' =>
    manager.include?('scope: hotKeyAction.scope.hotKeyScope'),
  'hotkey editor exposes a trigger-condition selector' =>
    view.include?('DropdownButtonFormField<HotKeyTriggerScope>') &&
      view.include?('appLocalizations.hotkeyTriggerCondition'),
  'hotkey list shows the selected trigger condition' =>
    view.include?('_hotKeyScopeLabel(context, hotKeyAction.scope)'),
  'hotkey scope persistence has focused regression tests' =>
    test.include?('HotKeyAction JSON') &&
      test.include?('legacy settings default to global triggering') &&
      test.include?('persists in-app triggering scope'),
  'hotkey scope mapping has a focused test' =>
    enum_test.include?('HotKeyTriggerScopeExt') &&
      enum_test.include?('HotKeyScope.inapp'),
  'all supported locales expose the selector text' =>
    Dir[File.join(root, 'arb', 'intl_*.arb')].all? do |path|
      content = File.read(path)
      content.include?('"hotkeyTriggerCondition"') &&
        content.include?('"hotkeyGlobal"') &&
        content.include?('"hotkeyInApp"')
    end,
}

failed = checks.each_with_object([]) do |(name, passed), names|
  names << name unless passed
end
abort "Hotkey scope verifier failed: #{failed.join(', ')}" unless failed.empty?

puts 'Hotkey trigger scope wiring verified'
