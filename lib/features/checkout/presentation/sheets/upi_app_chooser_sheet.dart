import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// §5c.4 — bottom sheet, no route. Chooses which UPI app receives the
/// hand-off.
///
/// **Scope note.** Real installed-app detection needs a platform channel
/// (`smart_auth` handles SMS retrieval, not app-intent resolution) this
/// step doesn't add — the list below is fixture data standing in for
/// on-device detection, consistent with Phase 1's fakes-first practice.
/// Returns the chosen app's name, or `null` for the UPI-ID fallback.
class UpiAppChooserSheet extends StatelessWidget {
  const UpiAppChooserSheet({super.key});

  static const _fixtureApps = ['Google Pay', 'PhonePe', 'Paytm'];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Space.x4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.checkoutAppChooserTitle, style: context.type.title),
            const SizedBox(height: Space.x2),
            for (final app in _fixtureApps)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: colors.textSecondary,
                ),
                title: Text(app),
                onTap: () => Navigator.of(context).pop(app),
              ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.badge_outlined, color: colors.textSecondary),
              title: Text(l10n.checkoutPayByUpiId),
              onTap: () => Navigator.of(context).pop(null),
            ),
          ],
        ),
      ),
    );
  }
}
