import 'package:fl_clash/common/linux_clipboard.dart';
import 'package:test/test.dart';

void main() {
  group('Linux clipboard command selection', () {
    test('prefers wl-copy in a native Wayland session', () {
      final commands = LinuxClipboard.commandCandidates({
        'XDG_SESSION_TYPE': 'wayland',
        'WAYLAND_DISPLAY': 'wayland-0',
        'DISPLAY': ':0',
      });

      expect(commands.first.executable, 'wl-copy');
      expect(commands.first.arguments, isEmpty);
    });

    test('prefers X11 helpers when the app is running through XWayland', () {
      final commands = LinuxClipboard.commandCandidates({
        'XDG_SESSION_TYPE': 'wayland',
        'WAYLAND_DISPLAY': 'wayland-0',
        'DISPLAY': ':0',
        'GDK_BACKEND': 'x11',
      });

      expect(commands.first.executable, 'xclip');
      expect(commands.first.arguments, ['-selection', 'clipboard']);
    });

    test('tries the next clipboard helper when one is unavailable', () async {
      final attempts = <String>[];
      final clipboard = LinuxClipboard(
        environment: const {
          'XDG_SESSION_TYPE': 'wayland',
          'WAYLAND_DISPLAY': 'wayland-0',
        },
        runCommand: (executable, arguments, text) async {
          attempts.add('$executable:${arguments.join(',')}:$text');
          return executable == 'xclip';
        },
      );

      final copied = await clipboard.copy('export all_proxy=http://127.0.0.1:7890');

      expect(copied, isTrue);
      expect(attempts, [
        'wl-copy::export all_proxy=http://127.0.0.1:7890',
        'xclip:-selection,clipboard:export all_proxy=http://127.0.0.1:7890',
      ]);
    });

    test('returns false when no helper accepts the content', () async {
      final clipboard = LinuxClipboard(
        environment: const {'DISPLAY': ':0'},
        runCommand: (executable, arguments, text) async => false,
      );

      expect(await clipboard.copy('copy me'), isFalse);
    });
  });

  test('builds the expected proxy command for each desktop shell', () {
    expect(
      buildProxyEnvironmentCommand(isWindows: false, port: 7890),
      'export all_proxy=http://127.0.0.1:7890',
    );
    expect(
      buildProxyEnvironmentCommand(isWindows: true, port: 7890),
      'set \$env:all_proxy=http://127.0.0.1:7890',
    );
  });
}
