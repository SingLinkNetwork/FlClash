#!/usr/bin/env ruby

window_source = File.read(File.expand_path('../lib/common/window.dart', __dir__))
system_source = File.read(File.expand_path('../lib/common/system.dart', __dir__))
action_source = File.read(File.expand_path('../lib/providers/action.dart', __dir__))
window_manager_source = File.read(
  File.expand_path('../lib/manager/window_manager.dart', __dir__),
)

required_patterns = {
  'Window.show resumes rendering before showing the window' =>
    /Future<void> show\(\) async \{.*?render\?\.resume\(\).*?windowManager\.show\(\)/m,
  'Window.hide pauses rendering before hiding the window' =>
    /Future<void> hide\(\) async \{.*?render\?\.pause\(\).*?windowManager\.hide\(\)/m,
  'System.back uses the render-aware window hide path' =>
    /Future<void> back\(\) async \{.*?await window\?\.hide\(\)/m,
  'visibility toggle uses the shared show and hide paths' =>
    /Future<void> updateVisible\(\) async \{.*?window\?\.show\(\).*?window\?\.hide\(\)/m,
  'minimize pauses rendering' =>
    /void onWindowMinimize\(\) async \{.*?render\?\.pause\(\)/m,
  'restore resumes rendering' =>
    /void onWindowRestore\(\).*?render\?\.resume\(\)/m,
}

sources = {
  'Window.show resumes rendering before showing the window' => window_source,
  'Window.hide pauses rendering before hiding the window' => window_source,
  'System.back uses the render-aware window hide path' => system_source,
  'visibility toggle uses the shared show and hide paths' => action_source,
  'minimize pauses rendering' => window_manager_source,
  'restore resumes rendering' => window_manager_source,
}

required_patterns.each do |description, pattern|
  abort "Desktop render visibility rule is missing: #{description}" unless
    sources.fetch(description).match?(pattern)
end

puts 'Desktop render pause/resume visibility chain verified'
