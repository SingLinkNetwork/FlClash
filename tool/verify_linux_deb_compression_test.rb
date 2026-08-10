#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'open3'
require 'rbconfig'
require 'tmpdir'

class VerifyLinuxDebCompressionTest < Minitest::Test
  SCRIPT = File.expand_path('verify_linux_deb_compression.rb', __dir__)

  def test_accepts_deb_with_gzip_control_and_data_members
    Dir.mktmpdir('flclash-deb-compression-test-') do |root|
      write_deb(
        File.join(root, 'FlClash-gzip.deb'),
        ['debian-binary', 'control.tar.gz', 'data.tar.gz'],
      )

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        SCRIPT,
        root,
      )

      assert status.success?, "expected gzip DEB to pass, got:\n#{stderr}"
    end
  end

  def test_rejects_deb_with_zstd_members
    Dir.mktmpdir('flclash-deb-compression-test-') do |root|
      write_deb(
        File.join(root, 'FlClash-zstd.deb'),
        ['debian-binary', 'control.tar.zst', 'data.tar.zst'],
      )

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        SCRIPT,
        root,
      )

      refute status.success?, 'expected zstd DEB to be rejected'
      assert_includes stderr, 'gzip'
    end
  end

  def test_rejects_deb_without_required_control_or_data_member
    Dir.mktmpdir('flclash-deb-compression-test-') do |root|
      write_deb(
        File.join(root, 'FlClash-incomplete.deb'),
        ['debian-binary', 'control.tar.gz'],
      )

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        SCRIPT,
        root,
      )

      refute status.success?, 'expected incomplete DEB to be rejected'
      assert_includes stderr, 'data.tar.gz'
    end
  end

  private

  def write_deb(path, members)
    File.open(path, 'wb') do |file|
      file.write("!<arch>\n")
      members.each_with_index do |name, index|
        payload = "member-#{index}\n"
        file.write(format_ar_header(name, payload.bytesize))
        file.write(payload)
        file.write("\n") if payload.bytesize.odd?
      end
    end
  end

  def format_ar_header(name, size)
    [
      "#{name}/".ljust(16),
      '0'.ljust(12),
      '0'.ljust(6),
      '0'.ljust(6),
      '100644'.ljust(8),
      size.to_s.ljust(10),
      "`\n",
    ].join
  end
end
