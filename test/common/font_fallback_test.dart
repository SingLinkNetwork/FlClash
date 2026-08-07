import 'package:fl_clash/common/font.dart';
import 'package:test/test.dart';

void main() {
  test('keeps CJK fonts ahead of generic Linux fallbacks', () {
    expect(appFontFamilyFallback, contains('Noto Sans CJK SC'));
    expect(appFontFamilyFallback, contains('Noto Sans CJK TC'));
    expect(appFontFamilyFallback, contains('WenQuanYi Zen Hei'));
    expect(
      appFontFamilyFallback.indexOf('Noto Sans CJK SC'),
      lessThan(appFontFamilyFallback.indexOf('WenQuanYi Zen Hei')),
    );
  });
}
