#!/usr/bin/env ruby

source = File.read(File.expand_path('../linux/runner/main.cc', __dir__))
project_cmake = File.read(File.expand_path('../linux/CMakeLists.txt', __dir__))
runner_cmake = File.read(File.expand_path('../linux/runner/CMakeLists.txt', __dir__))

include_index = source.index('#include <X11/Xlib.h>')
main_index = source.index('int main(')
init_index = source.index('XInitThreads();')
application_index = source.index('my_application_new();')
x11_package_index = project_cmake.index(
  'pkg_check_modules(X11 REQUIRED IMPORTED_TARGET x11)',
)
x11_link_index = runner_cmake.index('PkgConfig::X11')

abort 'Linux runner must include X11 Xlib declarations' unless include_index
abort 'Linux runner main is missing' unless main_index
abort 'Linux runner must initialize Xlib threads' unless init_index
abort 'XInitThreads must run before creating the GTK application' unless
  init_index < application_index
abort 'Linux CMake must declare the X11 pkg-config dependency' unless
  x11_package_index
abort 'Linux runner must link the X11 pkg-config dependency' unless
  x11_link_index

puts 'Linux X11 thread initialization verified'
