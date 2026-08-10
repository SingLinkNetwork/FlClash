#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'open3'
require 'rbconfig'
require 'tmpdir'

class VerifyLinuxPackagesTest < Minitest::Test
  SCRIPT = File.expand_path('verify_linux_packages.rb', __dir__)

  def test_rpm_pipeline_waits_for_commands_and_verifies_desktop_entry
    Dir.mktmpdir('flclash-package-verifier-test-') do |root|
      dist = File.join(root, 'dist')
      bin = File.join(root, 'bin')
      FileUtils.mkdir_p([dist, bin])
      FileUtils.touch(File.join(dist, 'FlClash-test.rpm'))

      write_executable(File.join(bin, 'rpm2cpio'), <<~RUBY)
        #!/usr/bin/env ruby
        puts 'fake rpm archive'
      RUBY
      write_executable(File.join(bin, 'cpio'), <<~RUBY)
        #!/usr/bin/env ruby
        require 'fileutils'
        FileUtils.mkdir_p('usr/share/applications')
        File.write('usr/share/applications/FlClash.desktop', "[Desktop Entry]\nStartupWMClass=com.follow.clash\n")
      RUBY

      env = { 'PATH' => "#{bin}:#{ENV.fetch('PATH')}" }
      _stdout, stderr, status = Open3.capture3(
        env,
        RbConfig.ruby,
        SCRIPT,
        dist,
        'rpm',
      )

      assert status.success?, "expected RPM verification to pass, got:\n#{stderr}"
    end
  end

  private

  def write_executable(path, content)
    File.write(path, content)
    FileUtils.chmod('+x', path)
  end
end
