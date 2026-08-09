/// CSV file download — real browser download on web, a no-op under
/// `flutter test`'s VM (see `csv_download_stub.dart`).
library;

export 'csv_download_stub.dart' if (dart.library.html) 'csv_download_web.dart';
