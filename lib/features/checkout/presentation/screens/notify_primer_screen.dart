import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/router/routes.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// §4.2 `/checkout/notify-primer/:orderId`, §5c.9 — requests notification
/// permission at the moment of peak consent (D2): money is now committed
/// and there's a genuine need for a pickup reminder.
///
/// **Scope note.** No real permission request happens yet — `PushProvider`
/// (Phase 8 §8.6) is `engagement`'s feature (step 8), same "sits behind a
/// core abstraction, not built until its owning feature lands" reasoning
/// as `PaymentGateway` before this step. Both CTAs below currently lead to
/// the same outcome (proceed, with the in-app-reminder note), which is
/// honest rather than simulated: neither claims a permission grant that
/// can't yet be requested. The destination is the `/orders` placeholder
/// tab, since `/orders/:id/pickup` (§5d.3) doesn't exist yet either
/// (`orders`, step 7).
class NotifyPrimerScreen extends StatefulWidget {
  const NotifyPrimerScreen({required this.orderId, super.key});

  final String orderId;

  @override
  State<NotifyPrimerScreen> createState() => _NotifyPrimerScreenState();
}

class _NotifyPrimerScreenState extends State<NotifyPrimerScreen> {
  bool _declined = false;

  void _proceed() {
    const OrdersRoute().go(context);
  }

  void _decline() {
    setState(() => _declined = true);
  }

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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              ExcludeSemantics(
                child: Icon(
                  Icons.notifications_active_outlined,
                  size: 96,
                  color: colors.actionSecondaryFg,
                ),
              ),
              const SizedBox(height: Space.x8),
              Text(
                l10n.notifyPrimerTitle,
                style: context.type.display,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Space.x6),
              for (final reason in [
                l10n.notifyPrimerReason1,
                l10n.notifyPrimerReason2,
                l10n.notifyPrimerReason3,
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.x1),
                  child: Row(
                    children: [
                      Icon(Icons.check, size: 18, color: colors.success.fg),
                      const SizedBox(width: Space.x2),
                      Expanded(child: Text(reason, style: context.type.body)),
                    ],
                  ),
                ),
              if (_declined) ...[
                const SizedBox(height: Space.x4),
                Text(
                  l10n.notifyPrimerDeniedNote,
                  style: context.type.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const Spacer(),
              AppButton(label: l10n.notifyPrimerAllow, onPressed: _proceed),
              const SizedBox(height: Space.x3),
              // Equal visual weight, not a greyed-out afterthought — same
              // principle as the manual-location option in §5a.3.
              AppButton(
                label: l10n.notifyPrimerDecline,
                variant: AppButtonVariant.secondary,
                onPressed: _declined ? _proceed : _decline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
