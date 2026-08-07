#!/usr/bin/env ruby

source = File.read(File.expand_path('../linux/runner/my_application.cc', __dir__))

required_patterns = {
  'Linux OpenGL probe creates a GDK context' =>
    /gdk_window_create_gl_context\(/,
  'Linux OpenGL probe realizes the GDK context' =>
    /gdk_gl_context_realize\(/,
  'renderer fallback selects Flutter software rendering' =>
    /g_setenv\(\s*['"]FLUTTER_LINUX_RENDERER['"]\s*,\s*['"]software['"]\s*,\s*TRUE\s*\)/,
  'renderer fallback is invoked before creating the Flutter view' =>
    /configure_linux_renderer\(\);.*?fl_view_new\(/m,
}

required_patterns.each do |description, pattern|
  abort "Linux renderer fallback rule is missing: #{description}" unless
    source.match?(pattern)
end

abort 'Linux renderer fallback must preserve explicit renderer settings' unless
  source.match?(/g_getenv\(\s*['"]FLUTTER_LINUX_RENDERER['"]\s*\)/)

puts 'Linux renderer fallback verified'
