#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'

root = File.expand_path(ARGV[1] || File.expand_path('..', __dir__))
workflow_path = File.expand_path(
  ARGV[0] || File.join(root, '.github', 'workflows', 'pull-request-validation.yaml'),
)

abort "Workflow file not found: #{workflow_path}" unless File.file?(workflow_path)

workflow = YAML.safe_load(File.read(workflow_path), aliases: true)
jobs = workflow.fetch('jobs')
errors = []

unless File.read(File.join(root, 'pubspec.yaml')).match?(/^\s+msix:\s+\^3\.18\.0\s*$/)
  errors << 'pubspec.yaml must pin msix ^3.18.0'
end

%w[verify_msix.ps1 bundle_msix.ps1 verify_msixbundle.ps1].each do |filename|
  unless File.file?(File.join(root, 'tool', filename))
    errors << "missing tool/#{filename}"
  end
end

msix_job = jobs['windows-msix']
if msix_job.nil?
  errors << 'workflow is missing windows-msix'
else
  matrix = msix_job.dig('strategy', 'matrix', 'include') || []
  expected_runners = {
    'x64' => 'windows-2022',
    'arm64' => 'windows-11-arm',
  }
  expected_flutter_architectures = {
    'x64' => 'x64',
    # subosito/flutter-action publishes the Windows SDK as x64. The ARM64
    # runner bootstraps the native Dart SDK and engine in a later step.
    'arm64' => 'x64',
  }
  expected_runners.each do |architecture, runner|
    entry = matrix.find { |item| item['architecture'] == architecture }
    if entry.nil?
      errors << "windows-msix matrix is missing #{architecture}"
    elsif entry['os'] != runner
      errors << "windows-msix #{architecture} must run on #{runner}"
    elsif entry['flutter_architecture'] != expected_flutter_architectures.fetch(architecture)
      errors << "windows-msix #{architecture} must use the x64 Flutter SDK bootstrap"
    end
  end

  steps = msix_job.fetch('steps', [])
  flutter_step = steps.find { |step| step['uses'] == 'subosito/flutter-action@v2' }
  unless flutter_step && flutter_step['id'] == 'flutter' &&
         flutter_step.dig('with', 'architecture') == '${{ matrix.flutter_architecture }}'
    errors << 'windows-msix must expose the Flutter cache path and select the matrix SDK architecture'
  end
  arm64_bootstrap = steps.find { |step| step['name'] == 'Bootstrap native ARM64 Flutter SDK' }
  unless arm64_bootstrap && arm64_bootstrap['if'].to_s.include?("matrix.architecture == 'arm64'") &&
         arm64_bootstrap['shell'] == 'pwsh' &&
         arm64_bootstrap['run'].to_s.include?('engine-dart-sdk.stamp') &&
         arm64_bootstrap['run'].to_s.include?('update_dart_sdk.ps1') &&
         arm64_bootstrap['run'].to_s.include?('windows_arm64') &&
         arm64_bootstrap['run'].to_s.include?('windows-arm64-release')
    errors << 'windows-msix must bootstrap and verify the native ARM64 Dart SDK and engine'
  end
  unless steps.any? { |step| step['run'].to_s.strip == 'dart setup.dart windows --targets msix -v' }
    errors << 'windows-msix must invoke the repository MSIX setup target'
  end
  unless steps.any? do |step|
    run = step['run'].to_s
    step['shell'] == 'pwsh' &&
      run.match?(/pwsh\s+-NoProfile\s+-File\s+tool\/verify_msix\.ps1/) &&
      run.include?('-PackagePath $packages[0].FullName') &&
      run.include?('-ExpectedArchitecture $env:EXPECTED_ARCHITECTURE')
  end
    errors << 'windows-msix must verify each native MSIX package'
  end
  upload_names = steps.each_with_object([]) do |step, names|
    next unless step['uses'] == 'actions/upload-artifact@v4'

    names << step.dig('with', 'name').to_s
  end
  unless upload_names.include?('windows-msix-${{ matrix.architecture }}')
    errors << 'windows-msix must upload one artifact per architecture'
  end
  upload_paths = steps.each_with_object([]) do |step, paths|
    next unless step['uses'] == 'actions/upload-artifact@v4'

    paths << step.dig('with', 'path').to_s
  end
  unless upload_paths.include?('dist/FlClash-${{ matrix.architecture }}.msix')
    errors << 'windows-msix must upload the verified architecture-specific MSIX'
  end
end

bundle_job = jobs['windows-msixbundle']
if bundle_job.nil?
  errors << 'workflow is missing windows-msixbundle'
else
  unless bundle_job['runs-on'] == 'windows-2022'
    errors << 'windows-msixbundle must run on windows-2022'
  end
  needs = Array(bundle_job['needs'])
  unless needs.include?('windows-msix')
    errors << 'windows-msixbundle must depend on windows-msix'
  end

  steps = bundle_job.fetch('steps', [])
  download_names = steps.each_with_object([]) do |step, names|
    next unless step['uses'] == 'actions/download-artifact@v4'

    names << step.dig('with', 'name').to_s
  end
  %w[windows-msix-x64 windows-msix-arm64].each do |name|
    unless download_names.include?(name)
      errors << "windows-msixbundle must download #{name}"
    end
  end
  unless steps.any? do |step|
    run = step['run'].to_s
    step['shell'] == 'pwsh' &&
      run.match?(/pwsh\s+-NoProfile\s+-File\s+tool\/bundle_msix\.ps1/) &&
      run.include?('-X64Package $x64') &&
      run.include?('-Arm64Package $arm64') &&
      run.include?('-OutputPath') &&
      run.include?('dist\\FlClash.msixbundle')
  end
    errors << 'windows-msixbundle must invoke bundle_msix.ps1'
  end
  unless steps.any? do |step|
    run = step['run'].to_s
    step['shell'] == 'pwsh' &&
      run.strip == 'pwsh -NoProfile -File tool/verify_msixbundle.ps1 -BundlePath dist/FlClash.msixbundle'
  end
    errors << 'windows-msixbundle must invoke verify_msixbundle.ps1'
  end
  upload_names = steps.each_with_object([]) do |step, names|
    next unless step['uses'] == 'actions/upload-artifact@v4'

    names << step.dig('with', 'name').to_s
  end
  unless upload_names.include?('windows-msixbundle')
    errors << 'windows-msixbundle must upload the final bundle'
  end
  upload_paths = steps.each_with_object([]) do |step, paths|
    next unless step['uses'] == 'actions/upload-artifact@v4'

    paths << step.dig('with', 'path').to_s
  end
  unless upload_paths.include?('dist/FlClash.msixbundle')
    errors << 'windows-msixbundle must upload the verified final bundle'
  end
end

bundler_path = File.join(root, 'tool', 'bundle_msix.ps1')
if File.file?(bundler_path)
  bundler = File.read(bundler_path)
  unless bundler.match?(/&\s*\$makeAppx\s+bundle\s+\/v\s+\/d\s+\$stageDirectory\s+\/p\s+\$resolvedOutput/)
    errors << 'bundle_msix.ps1 must invoke MakeAppx bundle'
  end
end

msix_verifier_path = File.join(root, 'tool', 'verify_msix.ps1')
if File.file?(msix_verifier_path)
  msix_verifier = File.read(msix_verifier_path)
  unless msix_verifier.include?('[BitConverter]::ToUInt16') &&
         msix_verifier.include?('0x8664') &&
         msix_verifier.include?('0xaa64')
    errors << 'verify_msix.ps1 must validate the executable PE machine type'
  end
end

static_entries = jobs.dig('static-source', 'strategy', 'matrix', 'include') || []
unless static_entries.any? { |entry| entry['script'] == 'tool/verify_msixbundle_pipeline.rb' }
  errors << 'static-source must run verify_msixbundle_pipeline.rb'
end

build_needs = Array(jobs.dig('build', 'needs'))
unless build_needs.include?('windows-msixbundle')
  errors << 'build must wait for windows-msixbundle'
end

gate_job = jobs['ci-complete']
if gate_job.nil?
  errors << 'workflow is missing ci-complete required-check gate'
else
  unless gate_job['if'].to_s.strip == '${{ always() }}'
    errors << 'ci-complete must run even when an upstream job fails'
  end
  unless Array(gate_job['needs']) == ['build']
    errors << 'ci-complete must depend on the complete build matrix'
  end
  gate_steps = gate_job.fetch('steps', [])
  unless gate_steps.any? do |step|
    step['if'].to_s.include?('needs.build.result != \'success\'') &&
      step['run'].to_s.strip == 'exit 1'
  end
    errors << 'ci-complete must fail when the build matrix is not successful'
  end
end

if errors.empty?
  puts 'MSIXBundle CI pipeline verifier passed.'
  exit 0
end

warn errors.map { |error| "ERROR: #{error}" }
exit 1
