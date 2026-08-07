#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'open3'
require 'rbconfig'
require 'tmpdir'

class VerifyMsixbundlePipelineTest < Minitest::Test
  SCRIPT = File.expand_path('verify_msixbundle_pipeline.rb', __dir__)

  def test_verifier_rejects_pipeline_without_bundle_job
    Dir.mktmpdir('flclash-msixbundle-verifier-test-') do |root|
      workflow = File.join(root, 'workflow.yml')
      File.write(workflow, <<~YAML)
        jobs:
          windows-msix:
            strategy:
              matrix:
                include:
                - architecture: x64
                  os: windows-2022
                  flutter_architecture: x64
                - architecture: arm64
                  os: windows-11-arm
                  flutter_architecture: x64
            steps:
            - id: flutter
              uses: subosito/flutter-action@v2
              with:
                architecture: ${{ matrix.flutter_architecture }}
            - name: Bootstrap native ARM64 Flutter SDK
              if: ${{ matrix.architecture == 'arm64' }}
              shell: pwsh
              run: |
                Remove-Item engine-dart-sdk.stamp
                update_dart_sdk.ps1
                windows_arm64
                windows-arm64-release
            - run: dart setup.dart windows --targets msix -v
            - uses: actions/upload-artifact@v4
              with:
                name: windows-msix-${{ matrix.architecture }}
                path: dist/FlClash-${{ matrix.architecture }}.msix
          static-source:
            strategy:
              matrix:
                include:
                  - script: tool/verify_msixbundle_pipeline.rb
          build:
            needs: [windows-msix]
      YAML
      write_pipeline_files(root)

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        SCRIPT,
        workflow,
        root,
      )

      refute status.success?
      assert_includes stderr, 'windows-msixbundle'
    end
  end

  def test_verifier_rejects_fake_bundle_command_mentions
    Dir.mktmpdir('flclash-msixbundle-verifier-test-') do |root|
      workflow = File.join(root, 'workflow.yml')
      File.write(workflow, valid_workflow_yaml.sub(
        'pwsh -NoProfile -File tool/bundle_msix.ps1',
        'Write-Host "bundle_msix.ps1"',
      ))
      write_pipeline_files(root)

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        SCRIPT,
        workflow,
        root,
      )

      refute status.success?
      assert_includes stderr, 'bundle_msix.ps1'
    end
  end

  def test_verifier_requires_a_single_required_check_gate
    Dir.mktmpdir('flclash-msixbundle-verifier-test-') do |root|
      workflow = File.join(root, 'workflow.yml')
      File.write(workflow, valid_workflow_yaml.sub(/\n  ci-complete:\n.*\z/m, "\n"))
      write_pipeline_files(root)

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        SCRIPT,
        workflow,
        root,
      )

      refute status.success?
      assert_includes stderr, 'ci-complete'
    end
  end

  def test_verifier_requires_native_executable_architecture_check
    Dir.mktmpdir('flclash-msixbundle-verifier-test-') do |root|
      workflow = File.join(root, 'workflow.yml')
      File.write(workflow, valid_workflow_yaml)
      write_pipeline_files(root)
      File.write(File.join(root, 'tool', 'verify_msix.ps1'), 'manifest-only')

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        SCRIPT,
        workflow,
        root,
      )

      refute status.success?
      assert_includes stderr, 'PE machine type'
    end
  end

  private

  def valid_workflow_yaml
    <<~YAML
      jobs:
        windows-msix:
          strategy:
            matrix:
              include:
                - architecture: x64
                  os: windows-2022
                  flutter_architecture: x64
                - architecture: arm64
                  os: windows-11-arm
                  flutter_architecture: x64
          steps:
            - id: flutter
              uses: subosito/flutter-action@v2
              with:
                architecture: ${{ matrix.flutter_architecture }}
            - name: Bootstrap native ARM64 Flutter SDK
              if: ${{ matrix.architecture == 'arm64' }}
              shell: pwsh
              run: |
                Remove-Item engine-dart-sdk.stamp
                update_dart_sdk.ps1
                windows_arm64
                windows-arm64-release
            - run: dart setup.dart windows --targets msix -v
            - shell: pwsh
              run: |
                pwsh -NoProfile -File tool/verify_msix.ps1 -PackagePath $packages[0].FullName -ExpectedArchitecture $env:EXPECTED_ARCHITECTURE
            - uses: actions/upload-artifact@v4
              with:
                name: windows-msix-${{ matrix.architecture }}
                path: dist/FlClash-${{ matrix.architecture }}.msix
        windows-msixbundle:
          runs-on: windows-2022
          needs: windows-msix
          steps:
            - uses: actions/download-artifact@v4
              with:
                name: windows-msix-x64
                path: msix-input/x64
            - uses: actions/download-artifact@v4
              with:
                name: windows-msix-arm64
                path: msix-input/arm64
            - shell: pwsh
              run: |
                pwsh -NoProfile -File tool/bundle_msix.ps1 -X64Package $x64 -Arm64Package $arm64 -OutputPath dist\\FlClash.msixbundle
            - shell: pwsh
              run: pwsh -NoProfile -File tool/verify_msixbundle.ps1 -BundlePath dist/FlClash.msixbundle
            - uses: actions/upload-artifact@v4
              with:
                name: windows-msixbundle
                path: dist/FlClash.msixbundle
        static-source:
          strategy:
            matrix:
              include:
                - script: tool/verify_msixbundle_pipeline.rb
        build:
          needs: [windows-msixbundle]
        ci-complete:
          if: ${{ always() }}
          needs: [build]
          steps:
            - if: needs.build.result != 'success'
              run: exit 1
    YAML
  end

  def write_pipeline_files(root)
    tool_dir = File.join(root, 'tool')
    FileUtils.mkdir_p(tool_dir)
    FileUtils.touch(File.join(tool_dir, 'verify_msix.ps1'))
    FileUtils.touch(File.join(tool_dir, 'bundle_msix.ps1'))
    FileUtils.touch(File.join(tool_dir, 'verify_msixbundle.ps1'))
    File.write(File.join(root, 'pubspec.yaml'), "dev_dependencies:\n  msix: ^3.18.0\n")
  end
end
