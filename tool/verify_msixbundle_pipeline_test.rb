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
                  - architecture: arm64
                    os: windows-11-arm
            steps:
              - run: dart setup.dart windows --targets msix
              - uses: actions/upload-artifact@v4
                with:
                  name: windows-msix-${{ matrix.architecture }}
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

  private

  def write_pipeline_files(root)
    tool_dir = File.join(root, 'tool')
    FileUtils.mkdir_p(tool_dir)
    FileUtils.touch(File.join(tool_dir, 'verify_msix.ps1'))
    FileUtils.touch(File.join(tool_dir, 'bundle_msix.ps1'))
    FileUtils.touch(File.join(tool_dir, 'verify_msixbundle.ps1'))
    File.write(File.join(root, 'pubspec.yaml'), "dev_dependencies:\n  msix: ^3.18.0\n")
  end
end
