#!/usr/bin/env ruby

window_source = File.read(File.expand_path('../lib/common/window.dart', __dir__))
queue_source = File.read(
  File.expand_path('../lib/common/window_visibility.dart', __dir__),
)
state_source = File.read(File.expand_path('../lib/state.dart', __dir__))
action_source = File.read(File.expand_path('../lib/providers/action.dart', __dir__))

required_patterns = {
  'visibility queue is defined' => [queue_source, /class WindowVisibilityQueue/],
  'window owns one visibility queue' => [window_source, /final WindowVisibilityQueue _visibilityQueue/],
  'show is queued' => [window_source, /Future<void> show\(\) \{.*?_visibilityQueue\.enqueue/m],
  'hide is queued' => [window_source, /Future<void> hide\(\) \{.*?_visibilityQueue\.enqueue/m],
  'startup waits for show' => [state_source, /await window\?\.show\(\)/],
  'startup waits for hide' => [state_source, /await window\?\.hide\(\)/],
  'visibility toggle waits for show' => [action_source, /await window\?\.show\(\)/],
  'visibility toggle waits for hide' => [action_source, /await window\?\.hide\(\)/],
}

required_patterns.each do |description, (source, pattern)|
  abort "Window visibility rule is missing: #{description}" unless source.match?(pattern)
end

puts 'Window visibility queue and startup ordering verified'
