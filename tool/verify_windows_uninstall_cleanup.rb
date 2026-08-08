#!/usr/bin/env ruby

script_path = ARGV.fetch(0, 'windows/packaging/exe/inno_setup.iss')
workflow_path = ARGV.fetch(1, '.github/workflows/pull-request-validation.yaml')

script = File.read(script_path)
workflow = File.read(workflow_path)
errors = []

required_script_fragments = [
  'Name: "{autoprograms}',
  'Filename: "{app}',
  'function InitializeUninstall(): Boolean;',
  "CmdLineParamExists('/CLEANUSERDATA')",
  "ExpandConstant('{userappdata}\\com.follow\\clash')",
  "ExpandConstant('{localappdata}\\com.follow\\clash')",
  "ExpandConstant('{app}\\data')",
  "ExpandConstant('{app}\\cache')",
]

required_script_fragments.each do |fragment|
  unless script.include?(fragment)
    errors << "Windows uninstaller must include #{fragment.inspect}"
  end
end

unless script.scan(/DelTree\(ExpandConstant\('[^']+'\), True, True, True\);/).length == 4
  errors << 'Windows uninstaller must recursively delete all four known data directories'
end

unless workflow.include?('Verify Windows uninstaller cleans user data') &&
       workflow.include?('/CLEANUSERDATA') &&
       workflow.include?('Test-Path') &&
       workflow.include?('autoprograms')
  errors << 'Windows CI must verify Start Menu and opted-in uninstall cleanup'
end

if errors.empty?
  puts 'Windows uninstall cleanup verifier passed.'
  exit 0
end

warn errors.map { |error| "ERROR: #{error}" }
exit 1
