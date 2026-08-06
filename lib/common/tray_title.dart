class TrayTitleCache {
  String? _lastTitle;

  String? next({required bool show, required String trafficTitle}) {
    final title = show ? trafficTitle : '';
    if (title == _lastTitle) {
      return null;
    }
    _lastTitle = title;
    return title;
  }

  void reset() {
    _lastTitle = null;
  }
}
