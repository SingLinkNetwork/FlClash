#!/usr/bin/env ruby
# frozen_string_literal: true

root = File.expand_path('..', __dir__)
read = ->(*parts) { File.read(File.join(root, *parts)) }

patch = read.call(
  'tool',
  'patches',
  '0001-android-disable-default-udp-listeners.patch',
)
attributes = read.call('.gitattributes')
applier = read.call('tool', 'apply_clash_meta_patches.dart')
patch_helper = read.call(
  'plugins',
  'setup',
  'buildkit',
  'build_tool',
  'lib',
  'src',
  'clash_meta_patches.dart',
)
build_tool = read.call(
  'plugins',
  'setup',
  'buildkit',
  'build_tool',
  'lib',
  'src',
  'build_tool.dart',
)
pr_workflow = read.call('.github', 'workflows', 'pull-request-validation.yaml')
release_workflow = read.call('.github', 'workflows', 'build.yaml')

checks = {
  'core patch pins listener/listener.go' =>
    patch.include?('diff --git a/listener/listener.go b/listener/listener.go'),
  'core patch includes a listener regression test' =>
    patch.include?('listener_security_test.go'),
  'core patch is checked out with LF line endings on every platform' =>
    attributes.include?('tool/patches/*.patch text eol=lf'),
  'command-line patch applier uses the build-tool helper' =>
    applier.include?('// ignore: avoid_relative_lib_imports') &&
      applier.include?('clash_meta_patches.dart'),
  'core patch helper references the Android UDP patch' =>
    patch_helper.include?('0001-android-disable-default-udp-listeners.patch'),
  'native build tool applies Clash.Meta patches' =>
    build_tool.include?('applyClashMetaPatches'),
  'PR CI applies Clash.Meta patches before direct core checks' =>
    pr_workflow.include?('Apply Clash.Meta patches'),
  'release CI applies Clash.Meta patches before direct core checks' =>
    release_workflow.include?('Apply Clash.Meta patches'),
}

failed = checks.reject { |_description, passed| passed }.keys
abort "Clash.Meta patch delivery verification failed: #{failed.join(', ')}" unless failed.empty?

puts 'Clash.Meta patch delivery verified'
