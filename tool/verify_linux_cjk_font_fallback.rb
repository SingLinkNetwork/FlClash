#!/usr/bin/env ruby
# frozen_string_literal: true

root = File.expand_path('..', __dir__)
font_source = File.read(File.join(root, 'lib', 'common', 'font.dart'))
application = File.read(File.join(root, 'lib', 'application.dart'))
debian = File.read(
  File.join(root, 'linux', 'packaging', 'deb', 'make_config.yaml'),
)

checks = {
  'CJK fallback lists Simplified Chinese Noto Sans' =>
    font_source.include?('Noto Sans CJK SC'),
  'CJK fallback lists Traditional Chinese Noto Sans' =>
    font_source.include?('Noto Sans CJK TC'),
  'CJK fallback includes WenQuanYi for Debian KDE installations' =>
    font_source.include?('WenQuanYi Zen Hei'),
  'light theme applies the CJK fallback list' =>
    application.scan('fontFamilyFallback: appFontFamilyFallback').length >= 2,
  'Debian packaging installs a complete CJK font family' =>
    debian.match?(/^\s*-\s*fonts-noto-cjk\s*$/),
}

failed = checks.each_with_object([]) do |(name, passed), names|
  names << name unless passed
end

abort "Linux CJK font fallback verifier failed: #{failed.join(', ')}" unless
  failed.empty?

puts 'Linux CJK font fallback verifier: PASS'
