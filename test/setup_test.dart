import 'package:test/test.dart';

import '../setup.dart' as setup;

void main() {
  group('setup.dart', () {
    test('parses -v as verbose mode', () {
      final results = setup.createSetupArgParser().parse(['android', '-v']);

      expect(results['verbose'], isTrue);
      expect(results.rest, ['android']);
    });

    test('omits verbose from flutter build args by default', () {
      final args = setup.createFlutterBuildArgs(
        platform: 'android',
        verbose: false,
      );

      expect(args, ['dart-define-from-file=env.json', 'split-per-abi']);
    });

    test('adds verbose to flutter build args with -v', () {
      final args = setup.createFlutterBuildArgs(
        platform: 'android',
        verbose: true,
      );

      expect(args, [
        'verbose',
        'dart-define-from-file=env.json',
        'split-per-abi',
      ]);
    });

    test('maps supported Windows host architectures to MSIX values', () {
      expect(setup.windowsMsixArchitecture('amd64'), 'x64');
      expect(setup.windowsMsixArchitecture('x64'), 'x64');
      expect(setup.windowsMsixArchitecture('ARM64'), 'arm64');
    });

    test('rejects unsupported Windows host architectures', () {
      expect(
        () => setup.windowsMsixArchitecture('ia32'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('creates release Windows build arguments from env.json', () {
      expect(setup.createWindowsMsixBuildArgs(verbose: false), [
        'build',
        'windows',
        '--release',
        '--dart-define-from-file=env.json',
      ]);
    });

    test('creates unsigned MSIX arguments with shared identity metadata', () {
      final args = setup.createMsixCreateArgs(
        architecture: 'arm64',
        outputDirectory: r'C:\workspace\dist',
      );

      expect(
        args,
        containsAllInOrder([
          'run',
          'msix:create',
          '--release',
          '--build-windows',
          'false',
          '--architecture',
          'arm64',
          '--output-path',
          r'C:\workspace\dist',
          '--identity-name',
          'com.singlinknetwork.flclash',
          '--publisher',
          'CN=SingLinkNetwork',
          '--sign-msix',
          'false',
        ]),
      );
    });
  });
}
