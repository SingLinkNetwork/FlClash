#!/usr/bin/env ruby

lib_source = File.read(File.expand_path('../core/lib.go', __dir__))
guard_source = File.read(File.expand_path('../core/tun_guard.go', __dir__))
cpp_source = File.read(
  File.expand_path('../android/core/src/main/cpp/core.cpp', __dir__),
)

expected_go_guard = 'tunCallbackAvailable(th.listener != nil, th.callback)'
abort 'Go TUN callback guard helper is missing' unless
  guard_source.include?('func tunCallbackAvailable(') &&
  guard_source.include?('listenerPresent && callback != nil')
abort 'Go protect and resolve paths must guard a missing callback' unless
  lib_source.scan(expected_go_guard).length == 2

function_start = cpp_source.index('call_tun_interface_resolve_process_impl(')
function_end = cpp_source.index("\n}\n\nstatic void call_invoke_interface_result_impl", function_start)
abort 'Android resolve_process JNI bridge is missing' unless function_start && function_end

function_source = cpp_source[function_start...function_end]
guard_index = function_source.index('if (tun_interface == nullptr)')
jni_call_index = function_source.index('env->CallObjectMethod')
abort 'Android JNI bridge must guard nullptr before CallObjectMethod' unless
  guard_index && jni_call_index && guard_index < jni_call_index
abort 'Android JNI bridge must return an allocated empty string for nullptr' unless
  function_source.include?('return strdup("");')
abort 'Android JNI bridge must include the strdup declaration' unless
  cpp_source.include?('#include <cstring>')

puts 'Android resolve_process JNI null guard verified'
