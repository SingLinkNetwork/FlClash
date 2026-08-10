import 'package:fl_clash/common/proxy_environment.dart';
import 'package:test/test.dart';

void main() {
  group('buildProxyEnvironmentShellCommand', () {
    test('formats Bash and Zsh exports', () {
      expect(
        buildProxyEnvironmentShellCommand(
          shell: ProxyEnvironmentShell.bash,
          port: 7890,
        ),
        'export all_proxy=http://127.0.0.1:7890',
      );
      expect(
        buildProxyEnvironmentShellCommand(
          shell: ProxyEnvironmentShell.zsh,
          port: 1080,
        ),
        'export all_proxy=http://127.0.0.1:1080',
      );
    });

    test('formats Fish global export', () {
      expect(
        buildProxyEnvironmentShellCommand(
          shell: ProxyEnvironmentShell.fish,
          port: 7891,
        ),
        'set -gx all_proxy http://127.0.0.1:7891',
      );
    });

    test('formats PowerShell environment assignment', () {
      expect(
        buildProxyEnvironmentShellCommand(
          shell: ProxyEnvironmentShell.powershell,
          port: 7892,
        ),
        "\$env:all_proxy = 'http://127.0.0.1:7892'",
      );
    });

    test('exposes stable menu labels for every supported shell', () {
      expect(
        ProxyEnvironmentShell.values.map((shell) => shell.label).toList(),
        ['Bash', 'Fish', 'Zsh', 'PowerShell'],
      );
    });
  });
}
