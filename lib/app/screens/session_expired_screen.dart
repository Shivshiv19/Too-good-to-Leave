import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/router/routes.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// Recovers from refresh-token failure (§4.2 `/session-expired`, §5a.11,
/// amendment A24) without alarming the user about their money.
///
/// The reassurance line is load-bearing: an unexpected sign-out in an app
/// holding a prepaid reservation reads as "my order is gone" to a user who
/// hasn't read anything else on the screen yet.
///
/// **Scope note.** Nothing currently triggers this route automatically —
/// the `core/network` `auth_interceptor.dart` that would detect a revoked
/// refresh-token family (A24) doesn't exist yet, since there's no HTTP layer.
/// The screen and route exist so `/auth/phone`'s re-entry path is already
/// correct once that interceptor lands.
class SessionExpiredScreen extends StatelessWidget {
  const SessionExpiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.x6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.sessionExpiredTitle,
                  style: context.type.title,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: Space.x3),
              Text(
                l10n.sessionExpiredBody,
                style: context.type.body.copyWith(
                  color: colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Space.x8),
              AppButton(
                label: l10n.sessionExpiredCta,
                onPressed: () => const PhoneEntryRoute().go(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
