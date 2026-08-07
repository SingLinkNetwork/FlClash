/// System font families used when the primary font has no CJK glyph.
///
/// Linux distributions do not provide one consistent default font. Keeping
/// the CJK families explicit lets Flutter ask fontconfig for a complete font
/// instead of stopping at a missing glyph box.
const appFontFamilyFallback = <String>[
  'Noto Sans CJK SC',
  'Noto Sans CJK TC',
  'Noto Sans CJK JP',
  'Noto Sans CJK KR',
  'WenQuanYi Zen Hei',
  'WenQuanYi Zen Hei Mono',
];
