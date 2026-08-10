#!/usr/bin/env ruby

require 'open3'

root = File.expand_path('..', __dir__)

Dir.chdir(root) do
  base = ENV['GITHUB_BASE_SHA']
  head = ENV.fetch('GITHUB_SHA', 'HEAD')

  commit_exists = lambda do |ref|
    system('git', 'cat-file', '-e', "#{ref}^{commit}", out: File::NULL, err: File::NULL)
  end

  range = if base && commit_exists.call(base) && commit_exists.call(head)
            ["#{base}...#{head}"]
          elsif commit_exists.call('HEAD^')
            ['HEAD^', 'HEAD']
          else
            []
          end

  changed_dart = if range.empty?
                   []
                 else
                   stdout, stderr, status = Open3.capture3(
                     'git',
                     'diff',
                     '--name-only',
                     '--diff-filter=ACMR',
                     *range,
                     '--',
                     '*.dart',
                   )
                   abort "Unable to determine changed Dart files: #{stderr}" unless status.success?
                   stdout.lines.map(&:strip).reject(&:empty?)
                 end

  files = changed_dart.select { |path| File.file?(path) }
  if files.empty?
    puts 'No changed Dart files require formatting verification.'
    exit 0
  end

  puts "Checking Dart format for #{files.length} changed file(s):"
  puts files
  dart = ENV.fetch('DART_BIN', 'dart')
  exit(system(dart, 'format', '--output=none', '--set-exit-if-changed', *files) ? 0 : 1)
end
