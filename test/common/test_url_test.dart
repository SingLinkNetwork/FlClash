import 'package:fl_clash/common/test_url.dart';
import 'package:test/test.dart';

void main() {
  group('resolveTestUrls', () {
    test('keeps the default first and removes invalid or duplicate URLs', () {
      expect(
        resolveTestUrls(
          defaultUrl: ' https://default.test/health ',
          customUrls: [
            'https://github.com',
            ' https://default.test/health',
            'not a url',
            '',
          ],
        ),
        ['https://default.test/health', 'https://github.com'],
      );
    });

    test('falls back to the built-in URL when every value is invalid', () {
      expect(resolveTestUrls(defaultUrl: '', customUrls: ['not a url']), [
        'https://www.gstatic.com/generate_204',
      ]);
    });
  });
}
