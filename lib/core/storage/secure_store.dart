import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper over `flutter_secure_storage` (Phase 8 §8.2) — **tokens
/// only**. Non-sensitive local flags belong in `prefs.dart` instead.
final class SecureStore {
  const SecureStore(this._storage);

  final FlutterSecureStorage _storage;

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<void> delete(String key) => _storage.delete(key: key);
}
