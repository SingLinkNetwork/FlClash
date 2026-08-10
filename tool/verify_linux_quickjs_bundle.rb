#!/usr/bin/env ruby

require 'open3'

source_path = File.expand_path('../linux/CMakeLists.txt', __dir__)
source = File.read(source_path)

required_fragments = [
  'set(FLUTTER_JS_QUICKJS_LIBRARY',
  'flutter/ephemeral/.plugin_symlinks/flutter_js/linux/shared/libquickjs_c_bridge_plugin.so',
  'install(FILES "${FLUTTER_JS_QUICKJS_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"',
]

required_fragments.each do |fragment|
  abort "Linux QuickJS packaging rule is missing: #{fragment}" unless source.include?(fragment)
end

if ARGV.first == '--source'
  puts 'Linux QuickJS packaging source rule verified'
  exit
end

bundle_path = ARGV.fetch(0, 'build/linux/x64/debug/bundle')
quickjs_binary = File.join(bundle_path, 'lib', 'libquickjs_c_bridge_plugin.so')
abort "Linux bundle not found: #{bundle_path}" unless Dir.exist?(bundle_path)
abort "Linux QuickJS bridge not found: #{quickjs_binary}" unless File.file?(quickjs_binary)

stdout, stderr, status = Open3.capture3('file', quickjs_binary)
abort "file failed (#{status.exitstatus}): #{stderr.strip}" unless status.success?
unless stdout.include?('ELF') && stdout.include?('shared object')
  abort "Linux QuickJS bridge is not an ELF shared object: #{stdout.strip}"
end

puts "Linux QuickJS bundle verified: #{quickjs_binary}"
