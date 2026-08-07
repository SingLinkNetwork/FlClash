#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'
require 'tmpdir'

root = File.expand_path('..', __dir__)
dist = File.expand_path(ARGV.fetch(0, 'dist'), root)
abort "Linux package directory not found: #{dist}" unless Dir.exist?(dist)

artifact_patterns = {
  'deb' => '*.deb',
  'rpm' => '*.rpm',
  'appimage' => '*.{appimage,AppImage}',
}
requested_formats = (ARGV[1] || artifact_patterns.keys.join(',')).split(',')
unknown_formats = requested_formats - artifact_patterns.keys
abort "Unknown Linux package formats: #{unknown_formats.join(', ')}" unless unknown_formats.empty?
artifact_patterns = artifact_patterns.slice(*requested_formats)

def run_pipeline!(commands, chdir:)
  statuses = Open3.pipeline(*commands, chdir: chdir)
  failed = statuses.find { |status| !status.success? }
  abort "Linux package extraction failed: #{failed}" if failed
end

def verify_desktop_entry!(path, artifact)
  abort "Desktop entry is missing from #{artifact}: #{path}" unless File.file?(path)

  content = File.read(path)
  matches = content.lines.grep(/^StartupWMClass=com\.follow\.clash\s*$/)
  abort "StartupWMClass is missing or incorrect in #{artifact}: #{path}" unless matches.length == 1
end

artifact_patterns.each do |format, pattern|
  artifacts = Dir[File.join(dist, pattern)].sort
  abort "No #{format} artifact found in #{dist}" if artifacts.empty?

  artifacts.each do |artifact|
    Dir.mktmpdir("flclash-#{format}-") do |extract_dir|
      case format
      when 'deb'
        stdout, stderr, status = Open3.capture3('dpkg-deb', '-x', artifact, extract_dir)
        abort "dpkg-deb failed for #{artifact}: #{stderr.strip}" unless status.success?
        desktop_entries = Dir[File.join(extract_dir, 'usr/share/applications/*.desktop')]
      when 'rpm'
        run_pipeline!([
          ['rpm2cpio', artifact],
          ['cpio', '-idm', '--quiet'],
        ], chdir: extract_dir)
        desktop_entries = Dir[File.join(extract_dir, 'usr/share/applications/*.desktop')]
      when 'appimage'
        stdout, stderr, status = Open3.capture3(
          artifact,
          '--appimage-extract',
          chdir: extract_dir,
        )
        abort "AppImage extraction failed for #{artifact}: #{stderr.strip}" unless status.success?
        desktop_entries = Dir[File.join(extract_dir, 'squashfs-root/*.desktop')]
      end

      abort "No desktop entry found in #{artifact}" if desktop_entries.empty?
      desktop_entries.each { |entry| verify_desktop_entry!(entry, artifact) }
      puts "#{format} package verified: #{File.basename(artifact)}"
    end
  end
end
