#!/usr/bin/env ruby
# frozen_string_literal: true

root = File.expand_path('..', __dir__)
patch = File.read(File.join(root, 'tool/flutter_distributor_startup_wm_class.patch'))
setup = File.read(File.join(root, 'setup.dart'))
workflow = File.read(
  File.join(root, '.github/workflows/pull-request-validation.yaml'),
)
release_workflow = File.read(File.join(root, '.github/workflows/build.yaml'))

checks = {
  'distributor patch targets the Debian maker' =>
    patch.include?('packages/flutter_app_packager/lib/src/makers/deb/app_package_maker_deb.dart'),
  'distributor patch forces gzip compression' =>
    patch.include?("'-Zgzip',"),
  'setup applies the pinned distributor patch' =>
    setup.include?('flutter_distributor_startup_wm_class.patch') &&
      setup.include?("['apply', '--recount', patchPath]"),
  'Linux CI verifies the generated DEB compression' =>
    workflow.include?('ruby tool/verify_linux_deb_compression.rb dist'),
  'DEB compression regression test is wired into Linux CI' =>
    workflow.include?('ruby tool/verify_linux_deb_compression_test.rb'),
  'release workflow verifies the generated DEB compression' =>
    release_workflow.include?('ruby tool/verify_linux_deb_compression.rb dist'),
  'release workflow runs the DEB compression regression test' =>
    release_workflow.include?('ruby tool/verify_linux_deb_compression_test.rb'),
}

failed = checks.select { |_name, passed| !passed }.map { |name, _passed| name }
abort "Linux DEB compression wiring failed: #{failed.join(', ')}" unless failed.empty?

puts 'Linux DEB gzip compression wiring verified'
