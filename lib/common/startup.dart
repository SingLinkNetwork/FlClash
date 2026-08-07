import 'dart:async';

const startProxyArgument = '--start';

bool shouldStartProxyFromArguments(List<String> arguments) {
  return arguments.contains(startProxyArgument);
}

Future<bool> startListenerBeforePublishingStatus({
  required Future<bool> Function() startListener,
  required void Function() updateRunTime,
  required Future<void> Function() updateTraffic,
}) async {
  final started = await startListener();
  if (!started) return false;

  updateRunTime();
  unawaited(updateTraffic());
  return true;
}
