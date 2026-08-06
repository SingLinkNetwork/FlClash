#!/usr/bin/env ruby

require 'open3'

app_path = ARGV.fetch(0, 'build/macos/Build/Products/Release/FlClash.app')
sqlite_binary = File.join(
  app_path,
  'Contents',
  'Frameworks',
  'CSQLite.framework',
  'Versions',
  'A',
  'CSQLite',
)

abort "Release app not found: #{app_path}" unless Dir.exist?(app_path)
abort "Bundled CSQLite framework not found: #{sqlite_binary}" unless File.file?(sqlite_binary)

def run!(*command)
  stdout, stderr, status = Open3.capture3(*command)
  return stdout if status.success?

  abort "#{command.join(' ')} failed (#{status.exitstatus}): #{stderr.strip}"
end

lipo_info = run!('lipo', '-info', sqlite_binary)
%w[x86_64 arm64].each do |architecture|
  abort "CSQLite framework is missing #{architecture}: #{lipo_info.strip}" unless lipo_info.include?(architecture)

  symbols = run!('nm', '-arch', architecture, '-gU', sqlite_binary)
  unless symbols.include?('_sqlite3_stmt_isexplain')
    abort "CSQLite #{architecture} is missing sqlite3_stmt_isexplain"
  end
end

version = run!('strings', sqlite_binary).lines.grep(/^#?3\./).first&.strip
version_suffix = version ? ", #{version}" : ''
puts "CSQLite bundle verified: x86_64 + arm64, sqlite3_stmt_isexplain present#{version_suffix}"
