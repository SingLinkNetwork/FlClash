#!/usr/bin/env ruby

root = File.expand_path('..', __dir__)
request = File.read(File.join(root, 'lib', 'common', 'request.dart'))
profile = File.read(File.join(root, 'lib', 'models', 'profile.dart'))
action = File.read(File.join(root, 'lib', 'providers', 'action.dart'))
profiles_view = File.read(File.join(root, 'lib', 'views', 'profiles', 'profiles.dart'))
pr_workflow = File.read(
  File.join(root, '.github', 'workflows', 'pull-request-validation.yaml'),
)
build_workflow = File.read(File.join(root, '.github', 'workflows', 'build.yaml'))

checks = {
  'request exposes a proxy-default route choice' =>
    request.include?('bool useProxy = true'),
  'request owns a dedicated direct client' =>
    request.include?('late final Dio _directDio'),
  'direct client forces DIRECT routing' =>
    request.include?("httpClient.findProxy = (_) => 'DIRECT';"),
  'request selects the direct client when requested' =>
    request.include?('final client = useProxy ? _clashDio : _directDio'),
  'profile update forwards the route choice' =>
    profile.include?("request.getFileResponseForUrl(\n      url,\n      useProxy: useProxy,"),
  'profile action forwards the route choice' =>
    action.include?('profile.update(useProxy: useProxy)'),
  'profile menu offers proxy sync' => profiles_view.include?('syncViaProxy'),
  'profile menu offers direct sync' => profiles_view.include?('syncDirect'),
  'direct menu action disables proxy' => profiles_view.include?('useProxy: false'),
  'PR CI runs the route verifier' =>
    pr_workflow.include?('id: subscription-sync-route') &&
      pr_workflow.include?('script: tool/verify_subscription_sync_route.rb'),
  'release CI runs the route verifier' =>
    build_workflow.include?('ruby tool/verify_subscription_sync_route.rb'),
  'release CI runs the route regression test' =>
    build_workflow.include?('flutter test test/common/request_test.dart'),
}

failed = checks.each_with_object([]) do |(description, passed), result|
  result << description unless passed
end
abort "Subscription sync route verifier failed: #{failed.join(', ')}" unless failed.empty?

puts 'Subscription direct/proxy sync wiring verified.'
