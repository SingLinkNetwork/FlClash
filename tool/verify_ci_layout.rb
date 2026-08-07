#!/usr/bin/env ruby

require 'yaml'

root = File.expand_path('..', __dir__)
workflow_path = File.join(root, '.github', 'workflows', 'pull-request-validation.yaml')
workflow = YAML.safe_load(File.read(workflow_path), aliases: true)
jobs = workflow.fetch('jobs')

required_jobs = %w[
  dart-format
  dart-analyze
  flutter-tests
  go-tests
  go-vet
  static-source
  build
]
missing_jobs = required_jobs.reject { |job| jobs.key?(job) }
abort "CI workflow is missing jobs: #{missing_jobs.join(', ')}" unless missing_jobs.empty?

static_entries = jobs.fetch('static-source').fetch('strategy').fetch('matrix').fetch('include')
abort 'CI static-source matrix must expose at least 20 independent checks' unless static_entries.length >= 20

expected_scripts = %w[
  tool/verify_lan_proxy_toggle.rb
  tool/verify_delay_test_concurrency.rb
  tool/verify_android_jni_resolve_guard.rb
  tool/verify_window_visibility_queue.rb
  tool/verify_linux_tray_clipboard.rb
  tool/verify_windows_paste_fix.rb
  tool/verify_windows_search_close.rb
  tool/verify_linux_renderer_fallback.rb
  tool/verify_linux_cjk_font_fallback.rb
  tool/verify_android_background_location_permission.rb
  tool/verify_android_tile_background_toggle.rb
  tool/verify_linux_x11_thread_init.rb
  tool/verify_windows_maximize_work_area.rb
  tool/verify_windows_proxy_shutdown.rb
  tool/verify_windows_tun_metric_cleanup.rb
  tool/verify_desktop_render_visibility.rb
  tool/verify_windows_wifi_ssid_plugin.rb
  tool/verify_macos_window_lifecycle.rb
  tool/verify_macos_tray_destroy.rb
  tool/verify_macos_wifi_ssid_plugin.rb
  tool/verify_ci_layout.rb
]
actual_scripts = static_entries.map { |entry| entry.fetch('script') }
missing_scripts = expected_scripts.reject { |script| actual_scripts.include?(script) }
abort "CI static-source matrix is missing verifiers: #{missing_scripts.join(', ')}" unless missing_scripts.empty?

expected_build_needs = %w[dart-format dart-analyze flutter-tests go-tests go-vet static-source]
build_needs = Array(jobs.fetch('build').fetch('needs'))
missing_build_needs = expected_build_needs.reject { |job| build_needs.include?(job) }
abort "CI build job is missing prerequisites: #{missing_build_needs.join(', ')}" unless missing_build_needs.empty?

expected_scripts.each do |script|
  abort "CI verifier does not exist: #{script}" unless File.file?(File.join(root, script))
end

puts "CI layout verified: #{static_entries.length} independent static checks plus separate core and platform jobs"
