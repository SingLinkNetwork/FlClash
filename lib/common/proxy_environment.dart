enum ProxyEnvironmentShell { bash, fish, zsh, powershell }

extension ProxyEnvironmentShellPresentation on ProxyEnvironmentShell {
  String get label => switch (this) {
    ProxyEnvironmentShell.bash => 'Bash',
    ProxyEnvironmentShell.fish => 'Fish',
    ProxyEnvironmentShell.zsh => 'Zsh',
    ProxyEnvironmentShell.powershell => 'PowerShell',
  };
}

String buildProxyEnvironmentShellCommand({
  required ProxyEnvironmentShell shell,
  required int port,
}) {
  final url = 'http://127.0.0.1:$port';
  return switch (shell) {
    ProxyEnvironmentShell.bash ||
    ProxyEnvironmentShell.zsh => 'export all_proxy=$url',
    ProxyEnvironmentShell.fish => 'set -gx all_proxy $url',
    ProxyEnvironmentShell.powershell => '\$env:all_proxy = \'$url\'',
  };
}
