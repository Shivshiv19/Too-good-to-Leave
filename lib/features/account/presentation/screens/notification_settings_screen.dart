import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/design_system/components/always_on_preference_row.dart';
import 'package:surplus_marketplace/design_system/components/settings_list.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/account/account.dart';

/// §4.2 `/account/notifications`, §5f.4 — real control over **discovery**
/// notifications; transactional alerts stay always-on (§3.5 obligation 2).
///
/// **V1 scope: push only.** No OS-permission plumbing exists yet
/// (`PushProvider` is still an open item from Steps 6–8), so the
/// `permissionDenied` state/banner is not reachable in this build — see
/// the implementation log.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  NotificationPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await ref
        .read(accountRepositoryProvider)
        .getNotificationPreferences();
    if (mounted) setState(() => _prefs = prefs);
  }

  Future<void> _update(NotificationPreferences next) async {
    final previous = _prefs;
    setState(() => _prefs = next);
    try {
      await ref
          .read(accountRepositoryProvider)
          .setNotificationPreferences(next);
    } on Object {
      if (mounted) setState(() => _prefs = previous);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final prefs = _prefs;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        elevation: 0,
        title: Text(l10n.accountNotificationSettings),
      ),
      body: SafeArea(
        child: prefs == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  SettingsGroup(
                    title: l10n.notifSettingsOrderUpdates,
                    rows: [
                      AlwaysOnPreferenceRow(
                        title: l10n.notifSettingsOrderUpdatesLabel,
                        alwaysOnLabel: l10n.notificationsAlwaysOn,
                        semanticLabel: l10n.notificationAlwaysOnSemantic(
                          l10n.notifSettingsOrderUpdatesLabel,
                        ),
                      ),
                    ],
                  ),
                  SettingsGroup(
                    title: l10n.notifSettingsDiscovery,
                    rows: [
                      SwitchListTile(
                        title: Text(l10n.notifTypeNewBagsNearby),
                        value: prefs.newBagsNearby,
                        onChanged: (v) =>
                            _update(prefs.copyWith(newBagsNearby: v)),
                      ),
                      SwitchListTile(
                        title: Text(l10n.notifTypeWatchedMerchantListed),
                        value: prefs.watchedMerchantListed,
                        onChanged: (v) =>
                            _update(prefs.copyWith(watchedMerchantListed: v)),
                      ),
                    ],
                  ),
                  SettingsGroup(
                    title: l10n.notifSettingsOther,
                    rows: [
                      SwitchListTile(
                        title: Text(l10n.notifTypeRateYourPickup),
                        value: prefs.rateYourPickup,
                        onChanged: (v) =>
                            _update(prefs.copyWith(rateYourPickup: v)),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.x6),
                ],
              ),
      ),
    );
  }
}
