#!/usr/bin/env ruby
# frozen_string_literal: true

root = File.expand_path('..', __dir__)
dist = File.expand_path(ARGV.fetch(0, 'dist'), root)
abort "Linux package directory not found: #{dist}" unless Dir.exist?(dist)

artifacts = Dir[File.join(dist, '*.deb')].sort
abort "No .deb artifact found in #{dist}" if artifacts.empty?

def ar_members(path)
  bytes = File.binread(path)
  abort "Invalid Debian ar magic in #{path}" unless bytes.start_with?("!<arch>\n")

  members = []
  offset = 8
  while offset < bytes.bytesize
    header = bytes.byteslice(offset, 60)
    abort "Truncated ar header in #{path}" unless header&.bytesize == 60
    abort "Invalid ar header terminator in #{path}" unless header.byteslice(58, 2) == "`\n"

    name = header.byteslice(0, 16).strip
    size_text = header.byteslice(48, 10).strip
    size = Integer(size_text, 10)
    offset += 60
    abort "Truncated ar member #{name} in #{path}" if offset + size > bytes.bytesize

    members << name.delete_suffix('/')
    offset += size
    offset += 1 if size.odd?
  end

  abort "Trailing bytes after ar members in #{path}" unless offset == bytes.bytesize
  members
rescue ArgumentError
  abort "Invalid ar member size in #{path}"
end

artifacts.each do |artifact|
  members = ar_members(artifact)
  required = %w[debian-binary control.tar.gz data.tar.gz]
  missing = required - members
  unless missing.empty?
    abort "#{File.basename(artifact)} is missing required gzip member(s): #{missing.join(', ')}"
  end

  tar_members = members.grep(/\A(?:control|data)\.tar\./)
  unexpected = tar_members - %w[control.tar.gz data.tar.gz]
  unless unexpected.empty?
    abort "#{File.basename(artifact)} contains non-gzip Debian member(s): #{unexpected.join(', ')}"
  end

  puts "DEB gzip compression verified: #{File.basename(artifact)}"
end
