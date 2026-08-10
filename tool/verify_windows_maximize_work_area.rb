#!/usr/bin/env ruby

source = File.read(File.expand_path('../windows/runner/win32_window.cpp', __dir__))

required_fragments = [
  'case WM_GETMINMAXINFO:',
  'MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST)',
  'GetMonitorInfo',
  'rcWork',
  'ptMaxPosition',
  'ptMaxSize',
]

required_fragments.each do |fragment|
  abort "Windows runner is missing maximize work-area handling: #{fragment}" unless
    source.include?(fragment)
end

message_index = source.index('case WM_GETMINMAXINFO:')
fallback_index = source.index('return DefWindowProc(window_handle_, message, wparam, lparam);')
abort 'Windows maximize work-area handling must be inside MessageHandler' unless
  message_index && fallback_index && message_index < fallback_index

puts 'Windows maximize work-area handling verified'
