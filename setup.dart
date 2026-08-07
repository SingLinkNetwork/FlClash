import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

const _allTargets = <String, String>{
  'android': 'apk',
  'linux': 'deb', // appimage + rpm added for amd64 only
  'macos': 'dmg',
  'windows': 'exe,zip',
};

const _androidFlutterTarget = {
  'arm': 'android-arm',
  'arm64': 'android-arm64',
  'amd64': 'android-x64',
};

const _hostPlatform = {
  'linux': 'linux',
  'macos': 'macos',
  'windows': 'windows',
};

const _flutterDistributorRepository =
    'https://github.com/chen08209/flutter_distributor.git';
const _flutterDistributorRef = 'cdeeef2d8f8325bb6ae0bc86b39f56e4325d1a58';
const _flutterDistributorPackagePath = 'packages/flutter_distributor';

Future<void> main(List<String> args) async {
  final parser = createSetupArgParser();

  if (args.contains('--help') || args.contains('-h')) {
    _showHelp(parser);
    exit(0);
  }

  final results = parser.parse(args);
  final rest = results.rest;

  final hostOs = Platform.operatingSystem;
  final host = _hostPlatform[hostOs];
  if (host == null) {
    stderr.writeln('Unsupported host platform: $hostOs');
    exit(1);
  }

  final platform = rest.isNotEmpty ? rest.first : host;

  if (platform != host && platform != 'android') {
    stderr.writeln(
      'Cannot build "$platform" on $hostOs. Allowed: $host, android',
    );
    _showHelp(parser);
    exit(1);
  }

  final env = results['env'] as String;
  final rootDir = Directory.current.path;
  final arch = _detectArch();
  final targets = _getTargets(platform, arch, results['targets']);
  final androidArch = results['arch'] as String?;
  final verbose = results['verbose'] as bool;

  final exitCode = await _package(
    platform,
    env,
    targets,
    rootDir,
    arch,
    androidArch: androidArch,
    verbose: verbose,
  );
  exit(exitCode);
}

ArgParser createSetupArgParser() {
  return ArgParser()
    ..addOption(
      'env',
      defaultsTo: 'pre',
      allowed: ['pre', 'stable'],
      help: 'Application environment',
    )
    ..addOption(
      'targets',
      valueHelp: 'exe,zip,msix,dmg,apk,...',
      help: 'Package targets (default: all for platform)',
    )
    ..addOption(
      'arch',
      valueHelp: 'arm,arm64,amd64',
      allowed: ['arm', 'arm64', 'amd64'],
      help: 'Target architecture (Android only)',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Enable verbose Flutter build output',
    );
}

String windowsMsixArchitecture(String hostArch) {
  switch (hostArch.toLowerCase()) {
    case 'amd64':
    case 'x64':
      return 'x64';
    case 'arm64':
      return 'arm64';
    default:
      throw ArgumentError.value(
        hostArch,
        'hostArch',
        'Windows MSIX supports only amd64/x64 and arm64 hosts',
      );
  }
}

List<String> createWindowsMsixBuildArgs({required bool verbose}) {
  return [
    'build',
    'windows',
    '--release',
    if (verbose) '--verbose',
    '--dart-define-from-file=env.json',
  ];
}

List<String> createMsixCreateArgs({
  required String architecture,
  required String outputDirectory,
}) {
  return [
    'run',
    'msix:create',
    '--release',
    '--build-windows',
    'false',
    '--architecture',
    architecture,
    '--output-path',
    outputDirectory,
    '--output-name',
    'FlClash-$architecture',
    '--display-name',
    'FlClash',
    '--publisher-display-name',
    'SingLinkNetwork',
    '--identity-name',
    'com.singlinknetwork.flclash',
    '--publisher',
    'CN=SingLinkNetwork',
    '--capabilities',
    'internetClient',
    '--sign-msix',
    'false',
    '--install-certificate',
    'false',
  ];
}

List<String> createFlutterBuildArgs({
  required String platform,
  required bool verbose,
}) {
  final flutterBuildArgs = <String>[
    if (verbose) 'verbose',
    'dart-define-from-file=env.json',
  ];
  if (platform == 'android') {
    flutterBuildArgs.add('split-per-abi');
  }
  return flutterBuildArgs;
}

String _getTargets(String platform, String arch, String? customTargets) {
  if (customTargets != null) return customTargets;
  if (platform == 'linux' && arch == 'amd64') return 'deb,appimage,rpm';
  return _allTargets[platform]!;
}

void _showHelp(ArgParser parser) {
  stderr.writeln('Usage: dart setup.dart [platform] [options]');
  stderr.writeln('Platform: current host platform (default) or android');
  stderr.writeln();
  stderr.writeln('Default package targets:');
  _allTargets.forEach((p, t) => stderr.writeln('  $p: $t'));
  stderr.writeln();
  stderr.writeln(parser.usage);
}

Future<int> _package(
  String platform,
  String env,
  String targets,
  String rootDir,
  String arch, {
  String? androidArch,
  required bool verbose,
}) async {
  final coreSha256 = platform == 'windows' ? await _buildGoCore(rootDir) : null;

  final file = File(p.join(rootDir, 'env.json'));

  await file.writeAsString(
    jsonEncode({'APP_ENV': env, 'CORE_SHA256': ?coreSha256}),
  );

  final flutterBuildArgs = createFlutterBuildArgs(
    platform: platform,
    verbose: verbose,
  );
  final descriptionArgs = <String>[];
  if (platform != 'android') {
    descriptionArgs.addAll(['--description', arch]);
  }

  final depExit = await _ensureDependencies(platform, arch);
  if (depExit != 0) return depExit;

  if (platform == 'windows' && _isMsixOnlyTarget(targets)) {
    return _packageWindowsMsix(rootDir: rootDir, arch: arch, verbose: verbose);
  }

  final activateExit = await _activateFlutterDistributor(
    rootDir: rootDir,
    platform: platform,
  );
  if (activateExit != 0) return activateExit;

  final process = await Process.start(
    'flutter_distributor',
    [
      'package',
      '--skip-clean',
      '--platform',
      platform,
      '--targets',
      targets,
      if (androidArch != null)
        '--build-target-platform=${_androidFlutterTarget[androidArch]!}',
      if (flutterBuildArgs.isNotEmpty)
        '--flutter-build-args=${flutterBuildArgs.join(',')}',
      ...descriptionArgs,
    ],
    includeParentEnvironment: true,
    environment: {'ANDROID_ARCH': ?androidArch},
    runInShell: Platform.isWindows,
  );

  process.stdout.listen((data) {
    stdout.write(utf8.decode(data));
  });
  process.stderr.listen((data) {
    stderr.write(utf8.decode(data));
  });
  final exitCode = await process.exitCode;
  return exitCode;
}

bool _isMsixOnlyTarget(String targets) {
  final targetList = targets
      .split(',')
      .map((target) => target.trim())
      .where((target) => target.isNotEmpty)
      .toList();
  return targetList.length == 1 && targetList.single == 'msix';
}

Future<int> _packageWindowsMsix({
  required String rootDir,
  required String arch,
  required bool verbose,
}) async {
  final architecture = windowsMsixArchitecture(arch);
  final buildExit = await _runStreamingProcess(
    'flutter',
    createWindowsMsixBuildArgs(verbose: verbose),
    workingDirectory: rootDir,
  );
  if (buildExit != 0) return buildExit;

  return _runStreamingProcess(
    'dart',
    createMsixCreateArgs(
      architecture: architecture,
      outputDirectory: p.join(rootDir, 'dist'),
    ),
    workingDirectory: rootDir,
  );
}

Future<int> _runStreamingProcess(
  String executable,
  List<String> args, {
  required String workingDirectory,
}) async {
  final process = await Process.start(
    executable,
    args,
    workingDirectory: workingDirectory,
    includeParentEnvironment: true,
    runInShell: Platform.isWindows,
  );
  process.stdout.listen((data) {
    stdout.write(utf8.decode(data));
  });
  process.stderr.listen((data) {
    stderr.write(utf8.decode(data));
  });
  return process.exitCode;
}

Future<int> _activateFlutterDistributor({
  required String rootDir,
  required String platform,
}) async {
  if (platform != 'linux') {
    final result = await Process.run('dart', [
      'pub',
      'global',
      'activate',
      '-s',
      'git',
      _flutterDistributorRepository,
      '--git-ref',
      _flutterDistributorRef,
      '--git-path',
      _flutterDistributorPackagePath,
    ]);
    if (result.exitCode != 0) stderr.write(result.stderr);
    return result.exitCode;
  }

  final checkout = Directory(
    p.join(rootDir, '.dart_tool', 'flutter_distributor'),
  );
  if (checkout.existsSync()) {
    checkout.deleteSync(recursive: true);
  }

  final cloneResult = await Process.run('git', [
    'clone',
    '--filter=blob:none',
    '--no-checkout',
    _flutterDistributorRepository,
    checkout.path,
  ]);
  if (cloneResult.exitCode != 0) {
    stderr.write(cloneResult.stderr);
    return cloneResult.exitCode;
  }

  final fetchResult = await Process.run('git', [
    'fetch',
    '--depth=1',
    'origin',
    _flutterDistributorRef,
  ], workingDirectory: checkout.path);
  if (fetchResult.exitCode != 0) {
    stderr.write(fetchResult.stderr);
    return fetchResult.exitCode;
  }

  final checkoutResult = await Process.run('git', [
    'checkout',
    '--detach',
    'FETCH_HEAD',
  ], workingDirectory: checkout.path);
  if (checkoutResult.exitCode != 0) {
    stderr.write(checkoutResult.stderr);
    return checkoutResult.exitCode;
  }

  final patchPath = p.join(
    rootDir,
    'tool',
    'flutter_distributor_startup_wm_class.patch',
  );
  for (final args in [
    ['apply', '--recount', '--check', patchPath],
    ['apply', '--recount', patchPath],
  ]) {
    final patchResult = await Process.run(
      'git',
      args,
      workingDirectory: checkout.path,
    );
    if (patchResult.exitCode != 0) {
      stderr.write(patchResult.stderr);
      return patchResult.exitCode;
    }
  }

  final activateResult = await Process.run('dart', [
    'pub',
    'global',
    'activate',
    '-s',
    'path',
    p.join(checkout.path, _flutterDistributorPackagePath),
  ]);
  if (activateResult.exitCode != 0) stderr.write(activateResult.stderr);
  return activateResult.exitCode;
}

Future<String?> _buildGoCore(String rootDir) async {
  final buildToolDir = p.join(
    rootDir,
    'plugins',
    'setup',
    'buildkit',
    'build_tool',
  );
  final result = await Process.run('dart', [
    'run',
    'build_tool',
    'windows',
    '--root-dir',
    rootDir,
  ], workingDirectory: buildToolDir);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    return null;
  }
  final shaFile = File(p.join(rootDir, 'core_sha256.json'));
  if (!shaFile.existsSync()) return null;
  final content =
      jsonDecode(shaFile.readAsStringSync()) as Map<String, dynamic>;
  return content['CORE_SHA256'] as String?;
}

String _detectArch() {
  if (Platform.isWindows) {
    final pa = Platform.environment['PROCESSOR_ARCHITECTURE'] ?? 'AMD64';
    return pa.toUpperCase() == 'ARM64' ? 'arm64' : 'amd64';
  }
  final result = Process.runSync('uname', ['-m']);
  final machine = (result.stdout as String).trim();
  if (machine == 'aarch64') return 'arm64';
  if (machine == 'x86_64') return 'amd64';
  return machine;
}

Future<bool> _hasCommand(String cmd) async {
  final which = Platform.isWindows ? 'where' : 'command';
  final args = Platform.isWindows ? [cmd] : ['-v', cmd];
  final result = await Process.run(which, args);
  return result.exitCode == 0;
}

Future<int> _ensureDependencies(String platform, String arch) async {
  switch (platform) {
    case 'macos':
      return _ensureMacosDependencies();
    case 'linux':
      return _ensureLinuxDependencies(arch);
    default:
      return 0;
  }
}

Future<int> _ensureMacosDependencies() async {
  if (await _hasCommand('appdmg')) {
    stdout.writeln('appdmg already installed, skipping.');
    return 0;
  }
  stdout.writeln('Installing appdmg (DMG creator)...');
  final result = await Process.run('npm', ['install', '-g', 'appdmg']);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
  }
  return result.exitCode;
}

Future<int> _ensureLinuxDependencies(String arch) async {
  final pkgGroups = <List<String>>[
    ['ninja-build', 'libgtk-3-dev'],
    ['libayatana-appindicator3-dev'],
    ['libkeybinder-3.0-dev'],
    ['locate'],
  ];
  if (arch == 'amd64') {
    pkgGroups.addAll([
      ['rpm', 'patchelf'],
      ['libfuse2'],
    ]);
  }

  final missingGroups = <List<String>>[];
  for (final group in pkgGroups) {
    final missingPkgs = <String>[];
    for (final pkg in group) {
      if (!await _isDebianPackageInstalled(pkg)) {
        missingPkgs.add(pkg);
      }
    }
    if (missingPkgs.isNotEmpty) {
      missingGroups.add(missingPkgs);
    }
  }

  if (missingGroups.isEmpty) {
    stdout.writeln('All Linux build dependencies already installed, skipping.');
  } else {
    stdout.writeln('Updating apt package lists...');
    final updateExit = await _runLinuxDependencyCommand([
      'apt-get',
      'update',
      '-y',
    ]);
    if (updateExit != 0) {
      stderr.writeln(
        'apt-get update exited with $updateExit; continuing and verifying '
        'dependency installation directly.',
      );
    }

    for (final missingPkgs in missingGroups) {
      stdout.writeln(
        'Installing Linux build dependencies: ${missingPkgs.join(', ')}...',
      );
      final installExit = await _installLinuxPackages(missingPkgs);
      if (installExit != 0) return installExit;
    }
  }

  if (arch == 'amd64') {
    const appimagetool = '/usr/local/bin/appimagetool';
    if (File(appimagetool).existsSync()) {
      stdout.writeln('appimagetool already installed, skipping.');
      return 0;
    }
    stdout.writeln('Downloading appimagetool...');
    final downloadName = arch == 'amd64' ? 'x86_64' : 'aarch64';
    final dlResult = await Process.run('wget', [
      '-O',
      appimagetool,
      'https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-$downloadName.AppImage',
    ]);
    if (dlResult.exitCode != 0) {
      stderr.write(dlResult.stderr);
      return dlResult.exitCode;
    }
    await Process.run('chmod', ['+x', appimagetool]);
  }

  return 0;
}

Future<bool> _isDebianPackageInstalled(String pkg) async {
  final result = await Process.run('dpkg', ['-s', pkg]);
  return result.exitCode == 0 &&
      (result.stdout as String).contains('Status: install ok installed');
}

Future<bool> _areDebianPackagesInstalled(List<String> pkgs) async {
  for (final pkg in pkgs) {
    if (!await _isDebianPackageInstalled(pkg)) {
      return false;
    }
  }
  return true;
}

Future<int> _installLinuxPackages(List<String> pkgs) async {
  final exitCode = await _runLinuxDependencyCommand([
    'apt-get',
    'install',
    '-y',
    ...pkgs,
  ]);
  if (exitCode == 0) return 0;

  if (await _areDebianPackagesInstalled(pkgs)) {
    stderr.writeln(
      'apt-get install exited with $exitCode, but all requested packages are '
      'installed; continuing.',
    );
    return 0;
  }

  return exitCode;
}

Future<int> _runLinuxDependencyCommand(List<String> command) async {
  final sudoCommand = [
    'env',
    'DEBIAN_FRONTEND=noninteractive',
    'NEEDRESTART_MODE=a',
    ...command,
  ];
  stdout.writeln('exec: sudo ${sudoCommand.join(' ')}');
  final result = await Process.start('sudo', sudoCommand);
  result.stdout.listen((data) {
    stdout.write(utf8.decode(data));
  });
  result.stderr.listen((data) {
    stderr.write(utf8.decode(data));
  });
  final exitCode = await result.exitCode;
  if (exitCode != 0) {
    stderr.writeln('Linux dependency command failed with exit code $exitCode.');
  }
  return exitCode;
}
