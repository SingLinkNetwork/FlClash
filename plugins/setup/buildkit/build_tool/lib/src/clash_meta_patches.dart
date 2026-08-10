import 'dart:io';

const _patchFileNames = <String>[
  '0001-android-disable-default-udp-listeners.patch',
];

Future<void> applyClashMetaPatches(String rootDir) async {
  final coreDir = Directory('$rootDir/core/Clash.Meta');
  if (!coreDir.existsSync()) {
    throw FileSystemException('Clash.Meta submodule is missing', coreDir.path);
  }

  for (final patchName in _patchFileNames) {
    final patch = File('$rootDir/tool/patches/$patchName');
    if (!patch.existsSync()) {
      throw FileSystemException('Clash.Meta patch is missing', patch.path);
    }

    final alreadyApplied = await _gitApply(coreDir.path, [
      '--reverse',
      '--check',
      patch.path,
    ]);
    if (alreadyApplied.exitCode == 0) {
      stdout.writeln('Clash.Meta patch already applied: $patchName');
      continue;
    }

    final check = await _gitApply(coreDir.path, [
      '--check',
      '--whitespace=error-all',
      patch.path,
    ]);
    if (check.exitCode != 0) {
      throw ProcessException(
        'git apply',
        ['--check', patch.path],
        _outputOf(check),
        check.exitCode,
      );
    }

    final applied = await _gitApply(coreDir.path, [
      '--whitespace=error-all',
      patch.path,
    ]);
    if (applied.exitCode != 0) {
      throw ProcessException(
        'git apply',
        [patch.path],
        _outputOf(applied),
        applied.exitCode,
      );
    }

    stdout.writeln('Applied Clash.Meta patch: $patchName');
  }
}

Future<ProcessResult> _gitApply(
  String workingDirectory,
  List<String> arguments,
) {
  return Process.run('git', [
    'apply',
    ...arguments,
  ], workingDirectory: workingDirectory);
}

String _outputOf(ProcessResult result) {
  return '${result.stdout}${result.stderr}'.trim();
}
