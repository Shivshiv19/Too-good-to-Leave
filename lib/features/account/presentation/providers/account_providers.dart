import 'package:flutter/material.dart' show ThemeMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:surplus_marketplace/features/account/domain/repositories/account_repository.dart';

part 'account_providers.g.dart';

/// The DI seam (Phase 8 §8.6). Overridden in `bootstrap.dart`.
@riverpod
AccountRepository accountRepository(Ref ref) => throw UnimplementedError(
  'accountRepositoryProvider has no override — set one in bootstrap.dart.',
);

/// The app's current theme mode (§5f.5). Defaults to [ThemeMode.system]
/// synchronously — what `MaterialApp.router` needs on the very first frame
/// — then self-corrects once the persisted choice loads from
/// `AccountRepository.getThemeMode` (a brief flash of the system default on
/// a cold start where the user previously chose Light/Dark, accepted as a
/// minor simplification rather than plumbing a second synchronous-at-
/// bootstrap seed like the repositories get).
///
/// [set] both updates the live theme (§5f.5 — immediately, no restart) and
/// persists it for next launch — the App Settings screen calls this one
/// method rather than two separate calls.
@riverpod
class ThemeModeController extends _$ThemeModeController {
  @override
  ThemeMode build() {
    _restore();
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    final persisted = await ref.read(accountRepositoryProvider).getThemeMode();
    state = persisted;
  }

  void set(ThemeMode mode) {
    state = mode;
    ref.read(accountRepositoryProvider).setThemeMode(mode);
  }
}
