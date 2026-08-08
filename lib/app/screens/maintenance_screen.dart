import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:surplus_marketplace/app/session/session_providers.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/core/utils/formatters.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// Terminal, blocking (§4.2 `/maintenance`, §4.7 back blocked).
///
/// §5a.10 — an unspecified outage reads as abandonment, so the ETA variant
/// is preferred whenever [SessionState.maintenanceEtaAt] is known.
class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final etaAt = ref.watch(sessionStateProvider).maintenanceEtaAt;

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
                Icon(Icons.build, size: 48, color: colors.actionSecondaryFg),
                const SizedBox(height: Space.x6),
                Text(
                  l10n.maintenanceTitle,
                  style: context.type.title,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.x3),
                Text(
                  etaAt == null
                      ? l10n.maintenanceBody
                      : l10n.maintenanceBodyWithEta(Fmt.expectedBy(etaAt)),
                  style: context.type.body.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
