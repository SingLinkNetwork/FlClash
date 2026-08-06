#!/usr/bin/env ruby

script_path = ARGV.fetch(0, 'windows/packaging/exe/inno_setup.iss')
workflow_path = ARGV.fetch(1, '.github/workflows/pull-request-validation.yaml')

script = File.read(script_path)
workflow = File.read(workflow_path)
errors = []

[
  'https://aka.ms/vc14/vc_redist.x64.exe',
  'https://aka.ms/vc14/vc_redist.arm64.exe',
  'DownloadTemporaryFile',
  'RegQueryDWordValue',
  'PrepareToInstall',
  '/install /quiet /norestart',
  'ResultCode = 3010',
].each do |required_text|
  unless script.include?(required_text)
    errors << "Windows installer must include #{required_text.inspect}"
  end
end

unless script.include?('VCRedistFileName')
  errors << 'Windows installer must select a redistributable filename by architecture'
end

unless script.include?('IsVCRedistInstalled')
  errors << 'Windows installer must skip the redistributable when it is already installed'
end

unless workflow.include?('Build Windows installer') &&
       workflow.include?('dart setup.dart windows --targets exe')
  errors << 'Pull Request CI must compile the Windows installer'
end

unless workflow.include?('Verify Windows installer installs Visual C++ runtime') &&
       workflow.include?('Start-Process -FilePath $installer.FullName') &&
       workflow.include?('HKLM:\\SOFTWARE\\Microsoft\\VisualStudio\\14.0\\VC\\Runtimes\\x64') &&
       workflow.include?('/VERYSILENT') &&
       workflow.include?('Invoke-WebRequest') &&
       workflow.include?('/uninstall')
  errors << 'Pull Request CI must execute the Windows installer and verify the Visual C++ runtime'
end

if errors.empty?
  puts 'Windows installer runtime verifier passed.'
  exit 0
end

warn errors.map { |error| "ERROR: #{error}" }
exit 1
