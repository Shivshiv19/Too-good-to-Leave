import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// Terminal, blocking (§4.2 `/force-update`, §4.7 back blocked).
///
/// Reached only via §4.3 rule 1, which outranks every other guard including
/// an in-flight payment — a client this old has been declared unsafe to
/// transact on.
///
/// **Open item found while implementing this screen.** `GET /v1/config`
/// (Phase 7 §7.3) has no `storeUrl` field — only `ForceUpdateException`
/// (`core/error/app_exception.dart`, thrown on a mid-session version
/// rejection) carries one. The Splash-driven path that reaches this screen
/// from [RemoteConfig.requiresForceUpdateFor] therefore has no store link to
/// offer yet. Rather than invent one, the CTA is disabled with the copy
/// deck's existing "couldn't open the store" line — see §7.3 for the
/// contract addition this needs (mirrors how A15 was flagged as a
/// `policyValues` gap).
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colors.surfaceBase,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Space.x6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.system_update,
                  size: 48,
                  color: colors.actionSecondaryFg,
                ),
                const SizedBox(height: Space.x6),
                Text(
                  l10n.forceUpdateTitle,
                  style: context.type.title,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.x3),
                Text(
                  l10n.forceUpdateBody,
                  style: context.type.body.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.x8),
                AppButton(
                  label: l10n.forceUpdateCta,
                  onPressed: null,
                  disabledReason: l10n.forceUpdateStoreUnavailable(
                    'the app store',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
