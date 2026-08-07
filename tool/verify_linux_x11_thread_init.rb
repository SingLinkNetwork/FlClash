#!/usr/bin/env ruby

source = File.read(File.expand_path('../linux/runner/main.cc', __dir__))

include_index = source.index('#include <X11/Xlib.h>')
main_index = source.index('int main(')
init_index = source.index('XInitThreads();')
application_index = source.index('my_application_new();')

abort 'Linux runner must include X11 Xlib declarations' unless include_index
abort 'Linux runner main is missing' unless main_index
abort 'Linux runner must initialize Xlib threads' unless init_index
abort 'XInitThreads must run before creating the GTK application' unless
  init_index < application_index

puts 'Linux X11 thread initialization verified'
