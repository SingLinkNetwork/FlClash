import 'constant.dart';

List<String> resolveTestUrls({
  required String defaultUrl,
  Iterable<String> customUrls = const [],
}) {
  final result = <String>[];
  for (final rawUrl in [defaultUrl, ...customUrls]) {
    final url = rawUrl.trim();
    final uri = Uri.tryParse(url);
    if (url.isEmpty ||
        uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        result.contains(url)) {
      continue;
    }
    result.add(url);
  }
  return result.isEmpty ? [defaultTestUrl] : result;
}

String testUrlLabel(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) {
    return url;
  }
  final path = uri.path == '/' ? '' : uri.path;
  return '${uri.host}$path';
}
