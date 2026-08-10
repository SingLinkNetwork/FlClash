#!/usr/bin/env ruby
# frozen_string_literal: true

root = File.expand_path('..', __dir__)
read = ->(path) { File.read(File.join(root, path)) }

expected_wm_class = 'com.follow.clash'
config_paths = [
  'linux/packaging/deb/make_config.yaml',
  'linux/packaging/rpm/make_config.yaml',
  'linux/packaging/appimage/make_config.yaml',
]

configs = config_paths.to_h { |path| [path, read.call(path)] }
setup = read.call('setup.dart')
patch = read.call('tool/flutter_distributor_startup_wm_class.patch')

checks = {
  'Linux package configs declare the application WM class' =>
    configs.values.all? { |content| content.include?("startup_wm_class: #{expected_wm_class}") },
  'the package patch adds the desktop entry field to every Linux format' =>
    %w[appimage deb rpm].all? do |format|
      patch.include?("packages/flutter_app_packager/lib/src/makers/#{format}/")
    end && patch.scan("'StartupWMClass'").length >= 3,
  'setup pins and patches the exact distributor revision' =>
    setup.include?('cdeeef2d8f8325bb6ae0bc86b39f56e4325d1a58') &&
      setup.include?('flutter_distributor_startup_wm_class.patch') &&
      setup.include?("'apply', '--recount', '--check'") &&
      setup.include?("['apply', '--recount', patchPath]"),
  'the runtime package identifier matches the desktop entry WM class' =>
    read.call('lib/common/constant.dart').include?("const packageName = '#{expected_wm_class}';"),
}

failed = checks.each_with_object([]) do |(name, passed), names|
  names << name unless passed
end
abort "Linux StartupWMClass verifier failed: #{failed.join(', ')}" unless failed.empty?

puts 'Linux StartupWMClass packaging wiring verified'
