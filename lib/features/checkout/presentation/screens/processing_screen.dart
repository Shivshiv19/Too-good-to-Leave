import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:surplus_marketplace/app/router/routes.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/core/payment/payment_gateway.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/design_system/foundations/motion.dart';
import 'package:surplus_marketplace/features/checkout/presentation/providers/checkout_providers.dart';

/// §4.2 `/checkout/processing`, §5c.5 — carries the user through gateway
/// initiation and the UPI app-switch with **no exit** (§4.7), while
/// remaining reassuring rather than frightening.
///
/// **Amendment A12.** Bounded to 60 s: after that, this screen
/// auto-transitions to `/checkout/verifying` regardless of whether
/// [PaymentGateway.launch] has returned, since an unbounded no-exit screen
/// is a trap no amount of correct reasoning about orphan payments
/// justifies (D-c3).
class ProcessingScreen extends ConsumerStatefulWidget {
  const ProcessingScreen({
    required this.orderId,
    required this.paymentId,
    required this.gatewayPayload,
    super.key,
  });

  final String orderId;
  final String paymentId;
  final String gatewayPayload;

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen> {
  static const _boundedDuration = Duration(seconds: 60);
  static const _slowThreshold = Duration(seconds: 15);

  Timer? _boundTimer;
  Timer? _slowTimer;
  bool _slow = false;
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    _boundTimer = Timer(_boundedDuration, _proceedToVerifying);
    _slowTimer = Timer(_slowThreshold, () {
      if (mounted) setState(() => _slow = true);
    });
    _launch();
  }

  @override
  void dispose() {
    _boundTimer?.cancel();
    _slowTimer?.cancel();
    super.dispose();
  }

  Future<void> _launch() async {
    try {
      await ref.read(paymentGatewayProvider).launch(widget.gatewayPayload);
      _proceedToVerifying();
    } on GatewayInitiationException {
      // The only exit from this screen — a redirect, never a back
      // navigation, and only reachable before any app-switch happened
      // (D-c3).
      if (_settled || !mounted) return;
      _settled = true;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.paymentGatewayUnreachable)));
      context.pop();
    }
  }

  void _proceedToVerifying() {
    if (_settled || !mounted) return;
    _settled = true;
    CheckoutVerifyingRoute(orderId: widget.orderId).go(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    return PopScope(
      // §4.7 — no exit while gateway initiation/app-switch is in flight.
      canPop: false,
      child: Scaffold(
        backgroundColor: colors.surfaceBase,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(Space.x6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (context.prefersReducedMotion)
                    Text(
                      l10n.processingTitle,
                      style: context.type.title,
                      textAlign: TextAlign.center,
                    )
                  else
                    CircularProgressIndicator(color: colors.actionPrimaryFg),
                  const SizedBox(height: Space.x6),
                  Text(
                    l10n.processingTitle,
                    style: context.type.title,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Space.x2),
                  // The absence of a back affordance must be explained in
                  // text — an unexplained trap is indistinguishable from a
                  // freeze, and a screen-reader user has no visual cue.
                  Text(
                    l10n.processingNoExit,
                    style: context.type.body.copyWith(
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_slow) ...[
                    const SizedBox(height: Space.x4),
                    Text(
                      l10n.processingSlow,
                      style: context.type.body.copyWith(
                        color: colors.attention.fg,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
