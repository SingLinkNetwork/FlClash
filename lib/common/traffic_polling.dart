bool shouldPollTraffic({
  required bool renderPaused,
  required bool showTrayTitle,
}) {
  return !renderPaused || showTrayTitle;
}

bool shouldHandleCoreRequestEvent({required bool renderPaused}) {
  return !renderPaused;
}
