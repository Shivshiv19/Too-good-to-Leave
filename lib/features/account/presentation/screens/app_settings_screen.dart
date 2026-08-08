import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/account/account.dart';

/// §4.2 `/account/settings`, §5f.5. **The language row is hidden while
/// only one locale ships** — a single-option picker implies missing
/// functionality (§5f.5's own rule); it appears once a second locale
/// lands.
class AppSettingsScreen extends ConsumerStatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  ConsumerState<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends ConsumerState<AppSettingsScreen> {
  bool _dataSaver = false;
  int? _cacheBytes;
  bool _clearing = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(accountRepositoryProvider);
    final dataSaver = await repo.getDataSaverEnabled();
    final size = await repo.cacheSizeBytes();
    if (!mounted) return;
    setState(() {
      _dataSaver = dataSaver;
      _cacheBytes = size;
      _loaded = true;
    });
  }

  // §5f.5 — applies immediately, no restart, no flash.
  void _setTheme(ThemeMode mode) =>
      ref.read(themeModeControllerProvider.notifier).set(mode);

  Future<void> _toggleDataSaver(bool value) async {
    setState(() => _dataSaver = value);
    await ref.read(accountRepositoryProvider).setDataSaverEnabled(value);
  }

  Future<void> _clearCache() async {
    setState(() => _clearing = true);
    try {
      await ref.read(accountRepositoryProvider).clearCache();
      if (mounted) setState(() => _cacheBytes = 0);
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  String _sizeLabel(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final currentTheme = ref.watch(themeModeControllerProvider);

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        elevation: 0,
        title: Text(l10n.accountAppSettings),
      ),
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: Space.x4),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.x4),
                    child: Text(
                      l10n.appSettingsTheme,
                      style: context.type.caption.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.system,
                    groupValue: currentTheme,
                    title: Text(l10n.appSettingsThemeSystem),
                    onChanged: (v) => _setTheme(v!),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.light,
                    groupValue: currentTheme,
                    title: Text(l10n.appSettingsThemeLight),
                    onChanged: (v) => _setTheme(v!),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.dark,
                    groupValue: currentTheme,
                    title: Text(l10n.appSettingsThemeDark),
                    onChanged: (v) => _setTheme(v!),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: Text(l10n.appSettingsDataSaver),
                    subtitle: Text(l10n.appSettingsDataSaverBody),
                    value: _dataSaver,
                    onChanged: _toggleDataSaver,
                  ),
                  const Divider(),
                  ListTile(
                    title: Text(l10n.appSettingsClearCache),
                    subtitle: Text(_sizeLabel(_cacheBytes ?? 0)),
                    trailing: _clearing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: _clearing ? null : _clearCache,
                  ),
                ],
              ),
      ),
    );
  }
}
