import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:surplus_marketplace/app/router/router.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/features/account/presentation/providers/account_providers.dart';

/// `MaterialApp.router` (Phase 8 §8.2).
///
/// Thin by design: theme, localisation, and routing wiring only. Every
/// screen-level decision lives in its own feature.
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    return MaterialApp.router(
      title: 'Too Good To Leave',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
