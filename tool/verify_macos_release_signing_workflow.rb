#!/usr/bin/env ruby
# frozen_string_literal: true

workflow_path = File.expand_path('../.github/workflows/release-macos-notarized.yaml', __dir__)
abort "Missing release signing workflow: #{workflow_path}" unless File.file?(workflow_path)

workflow = File.read(workflow_path)
required_markers = %w[
  workflow_dispatch
  APPLE_DEVELOPER_ID_P12_BASE64
  APPLE_DEVELOPER_ID_P12_PASSWORD
  APPLE_DEVELOPER_ID_APPLICATION
  APPLE_NOTARY_KEY_P8_BASE64
  APPLE_NOTARY_KEY_ID
  APPLE_NOTARY_ISSUER_ID
  codesign\ --verify\ --deep\ --strict\ --verbose=4
  xcrun\ notarytool\ submit
  xcrun\ stapler\ staple
  xcrun\ stapler\ validate
  spctl\ --assess\ --type\ execute\ --verbose=4
]

missing_markers = required_markers.reject { |marker| workflow.include?(marker) }
abort "Release signing workflow is missing: #{missing_markers.join(', ')}" unless missing_markers.empty?

abort 'Release signing workflow must use workflow_dispatch as its only trigger' unless
  workflow.match?(/^on:\s*\n\s+workflow_dispatch:/)

forbidden_triggers = %w[push pull_request pull_request_target schedule workflow_call repository_dispatch]
unexpected_triggers = forbidden_triggers.select { |trigger| workflow.match?(/^\s+#{Regexp.escape(trigger)}:/) }
abort "Release signing workflow must remain manual-only: #{unexpected_triggers.join(', ')}" unless unexpected_triggers.empty?

abort 'Release publication must be guarded by publish=true' unless workflow.include?("inputs.publish == 'true'")
abort 'Release publication must occur after Gatekeeper verification' unless
  workflow.index('Publish verified DMG') > workflow.rindex('spctl --assess --type execute --verbose=4')

puts 'macOS notarized release workflow verification passed'
