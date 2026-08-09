/// Non-web fallback (used when running under `flutter test`'s VM, which
/// has no `dart:html`) — a no-op, since there's no browser to hand a file
/// download to.
void downloadCsv(String filename, String content) {}
