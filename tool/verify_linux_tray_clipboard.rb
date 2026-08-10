#!/usr/bin/env ruby

tray_source = File.read(File.expand_path('../lib/common/tray.dart', __dir__))
clipboard_source = File.read(
  File.expand_path('../lib/common/linux_clipboard.dart', __dir__),
)

required_tray_fragments = [
  "import 'linux_clipboard.dart';",
  'system.isLinux && await (linuxClipboard?.copy(cmdline) ?? false)',
  'Clipboard.setData(ClipboardData(text: cmdline))',
]

required_tray_fragments.each do |fragment|
  abort "Linux tray clipboard integration is missing: #{fragment}" unless
    tray_source.include?(fragment)
end

required_clipboard_fragments = [
  "LinuxClipboardCommand('wl-copy', [])",
  "LinuxClipboardCommand('xclip', ['-selection', 'clipboard'])",
  "LinuxClipboardCommand('xsel', ['--clipboard', '--input'])",
  'return await process.exitCode.timeout',
]

required_clipboard_fragments.each do |fragment|
  abort "Linux clipboard fallback rule is missing: #{fragment}" unless
    clipboard_source.include?(fragment)
end

puts 'Linux tray clipboard fallback verified'
