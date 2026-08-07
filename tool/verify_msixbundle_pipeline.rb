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

%w[bundle_msix.ps1 verify_msixbundle.ps1].each do |filename|
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
  expected_runners.each do |architecture, runner|
    entry = matrix.find { |item| item['architecture'] == architecture }
    if entry.nil?
      errors << "windows-msix matrix is missing #{architecture}"
    elsif entry['os'] != runner
      errors << "windows-msix #{architecture} must run on #{runner}"
    end
  end

  steps = msix_job.fetch('steps', [])
  unless steps.any? { |step| step['run'].to_s.include?('dart setup.dart windows --targets msix') }
    errors << 'windows-msix must invoke the repository MSIX setup target'
  end
  upload_names = steps.each_with_object([]) do |step, names|
    next unless step['uses'] == 'actions/upload-artifact@v4'

    names << step.dig('with', 'name').to_s
  end
  unless upload_names.include?('windows-msix-${{ matrix.architecture }}')
    errors << 'windows-msix must upload one artifact per architecture'
  end
end

bundle_job = jobs['windows-msixbundle']
if bundle_job.nil?
  errors << 'workflow is missing windows-msixbundle'
else
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
  unless steps.any? { |step| step['run'].to_s.include?('bundle_msix.ps1') }
    errors << 'windows-msixbundle must invoke bundle_msix.ps1'
  end
  unless steps.any? { |step| step['run'].to_s.include?('verify_msixbundle.ps1') }
    errors << 'windows-msixbundle must invoke verify_msixbundle.ps1'
  end
  upload_names = steps.each_with_object([]) do |step, names|
    next unless step['uses'] == 'actions/upload-artifact@v4'

    names << step.dig('with', 'name').to_s
  end
  unless upload_names.include?('windows-msixbundle')
    errors << 'windows-msixbundle must upload the final bundle'
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

if errors.empty?
  puts 'MSIXBundle CI pipeline verifier passed.'
  exit 0
end

warn errors.map { |error| "ERROR: #{error}" }
exit 1
