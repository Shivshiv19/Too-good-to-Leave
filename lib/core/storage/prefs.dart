import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper over `shared_preferences` (Phase 8 §8.2 `core/storage`).
///
/// Holds **non-sensitive, local-only** flags and small values — onboarding
/// completion, a chosen dietary preset. Anything security-sensitive (tokens)
/// belongs in `secure_store.dart` instead, not here.
final class Prefs {
  const Prefs(this._instance);

  final SharedPreferences _instance;

  static Future<Prefs> open() async =>
      Prefs(await SharedPreferences.getInstance());

  bool? getBool(String key) => _instance.getBool(key);

  Future<void> setBool(String key, {required bool value}) =>
      _instance.setBool(key, value);

  String? getString(String key) => _instance.getString(key);

  Future<void> setString(String key, String value) =>
      _instance.setString(key, value);

  List<String>? getStringList(String key) => _instance.getStringList(key);

  Future<void> setStringList(String key, List<String> value) =>
      _instance.setStringList(key, value);

  Future<void> remove(String key) => _instance.remove(key);
}
