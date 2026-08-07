import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef LinuxClipboardCommandRunner = Future<bool> Function(
  String executable,
  List<String> arguments,
  String text,
);

class LinuxClipboardCommand {
  const LinuxClipboardCommand(this.executable, this.arguments);

  final String executable;
  final List<String> arguments;
}

class LinuxClipboard {
  LinuxClipboard({
    Map<String, String>? environment,
    LinuxClipboardCommandRunner? runCommand,
  }) : environment = environment ?? Platform.environment,
       runCommand = runCommand ?? _runCommand;

  final Map<String, String> environment;
  final LinuxClipboardCommandRunner runCommand;

  static List<LinuxClipboardCommand> commandCandidates(
    Map<String, String> environment,
  ) {
    final backend = environment['GDK_BACKEND']?.toLowerCase() ?? '';
    final isX11Backend = backend.split(',').contains('x11');
    final hasWayland =
        environment['WAYLAND_DISPLAY']?.isNotEmpty == true ||
        environment['XDG_SESSION_TYPE']?.toLowerCase() == 'wayland';

    const waylandCommands = [LinuxClipboardCommand('wl-copy', [])];
    const x11Commands = [
      LinuxClipboardCommand('xclip', ['-selection', 'clipboard']),
      LinuxClipboardCommand('xsel', ['--clipboard', '--input']),
    ];

    if (hasWayland && !isX11Backend) {
      return [...waylandCommands, ...x11Commands];
    }
    return [...x11Commands, ...waylandCommands];
  }

  Future<bool> copy(String text) async {
    for (final command in commandCandidates(environment)) {
      if (await runCommand(command.executable, command.arguments, text)) {
        return true;
      }
    }
    return false;
  }
}

Future<bool> _runCommand(
  String executable,
  List<String> arguments,
  String text,
) async {
  try {
    final process = await Process.start(executable, arguments);
    process.stdin.add(utf8.encode(text));
    await process.stdin.close();
    unawaited(process.stdout.drain());
    unawaited(process.stderr.drain());

    // xclip/xsel intentionally remain alive while they own the clipboard.
    // A short wait still catches an unavailable or immediately failing helper.
    try {
      return await process.exitCode.timeout(const Duration(milliseconds: 750)) ==
          0;
    } on TimeoutException {
      return true;
    }
  } on ProcessException {
    return false;
  } on OSError {
    return false;
  }
}

String buildProxyEnvironmentCommand({
  required bool isWindows,
  required int port,
}) {
  final url = 'http://127.0.0.1:$port';
  return isWindows ? 'set \$env:all_proxy=$url' : 'export all_proxy=$url';
}
