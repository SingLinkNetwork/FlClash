#!/usr/bin/env ruby

source = File.read(File.expand_path('../linux/runner/my_application.cc', __dir__))

required_patterns = {
  'Linux Nouveau driver detection inspects DRM sysfs' =>
    /g_dir_open\(\s*[\"']\/sys\/class\/drm[\"']/,
  'Linux Nouveau driver detection resolves the DRM driver link' =>
    /g_file_read_link\(/,
  'Linux Nouveau driver detection identifies the nouveau driver' =>
    /g_strrstr\(.*?nouveau/m,
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

configure_source = source
  .split('static void configure_linux_renderer()', 2)
  .last
  .split('// Implements GApplication::activate.', 2)
  .first
abort 'Linux renderer fallback must check Nouveau before probing OpenGL' unless
  configure_source.match?(/linux_nouveau_driver_present\(\).*?linux_opengl_context_available\(/m)

puts 'Linux renderer fallback verified'
