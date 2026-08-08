import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:surplus_marketplace/app/router/routes.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/core/utils/formatters.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/checkout/domain/entities/order.dart';
import 'package:surplus_marketplace/features/checkout/presentation/providers/checkout_providers.dart';

/// §4.2 `/checkout/failed?orderId=`, §5c.7 — recovers the sale without
/// leaving any doubt about the user's money.
///
/// **Amendment A13.** [Order.payment.chargeState] drives which of the two
/// authored variants renders — never a guess. **Hold status is the
/// difference between a recovered sale and a lost one** (spec's own
/// framing): this screen re-derives it from the same hold the order was
/// created from, via a fresh `CheckoutRepository.getHold` read rather than
/// assuming it's still alive.
class PaymentFailedScreen extends ConsumerStatefulWidget {
  const PaymentFailedScreen({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<PaymentFailedScreen> createState() =>
      _PaymentFailedScreenState();
}

class _PaymentFailedScreenState extends ConsumerState<PaymentFailedScreen> {
  static const _clock = SystemClock();

  Order? _order;
  DateTime? _holdExpiresAt;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(checkoutRepositoryProvider);
    final order = await repo.getOrder(widget.orderId);
    DateTime? holdExpiresAt;
    try {
      holdExpiresAt = (await repo.getHold(order.holdId)).expiresAt;
    } on HoldExpiredException {
      holdExpiresAt = null;
    }
    if (mounted) {
      setState(() {
        _order = order;
        _holdExpiresAt = holdExpiresAt;
      });
    }
  }

  String _reasonCopy(AppLocalizations l10n, String? reason) => switch (reason) {
    'declined' => l10n.paymentReasonDeclined,
    'insufficient_funds' => l10n.paymentReasonInsufficientFunds,
    'cancelled' => l10n.paymentReasonCancelled,
    'timeout' => l10n.paymentReasonTimeout,
    _ => l10n.paymentReasonUnknown,
  };

  String _chargeCopy(AppLocalizations l10n, ChargeState state) =>
      switch (state) {
        ChargeState.notCharged => l10n.chargeStateNotCharged,
        ChargeState.charged ||
        ChargeState.uncertain => l10n.chargeStateUncertain(3, 7),
      };

  Future<void> _retry() async {
    final order = _order!;
    setState(() => _retrying = true);
    if (_holdExpiresAt == null) {
      // Hold expired — one-tap re-reserve rather than a dead retry.
      if (mounted) {
        CheckoutRoute(
          bagId: order.bagSnapshot.bagId,
          quantity: order.quantity,
        ).go(context);
      }
      return;
    }
    try {
      final result = await ref
          .read(checkoutRepositoryProvider)
          .createOrder(
            holdId: order.holdId,
            customerId: order.customerId,
            method: order.payment.method,
          );
      if (!mounted) return;
      CheckoutProcessingRoute(
        orderId: result.order.id,
        paymentId: result.payment.id,
        gatewayPayload: result.gatewayPayload,
      ).go(context);
    } on Object {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final order = _order;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(backgroundColor: colors.surfaceBase, elevation: 0),
      body: SafeArea(
        child: order == null
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(Space.x6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.paymentFailedTitle, style: context.type.display),
                    const SizedBox(height: Space.x2),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _chargeCopy(l10n, order.payment.chargeState),
                        style: context.type.body.copyWith(
                          color: colors.critical.fg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.x2),
                    Text(
                      _reasonCopy(l10n, order.payment.failureReason),
                      style: context.type.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: Space.x4),
                    if (_holdExpiresAt != null)
                      Text(
                        l10n.paymentHoldStillActive(
                          Fmt.countdown(
                            _holdExpiresAt!.difference(_clock.now()),
                          ),
                        ),
                        style: context.type.body.copyWith(
                          color: colors.success.fg,
                        ),
                      )
                    else
                      Text(
                        l10n.cartHoldExpiredTitle,
                        style: context.type.body.copyWith(
                          color: colors.critical.fg,
                        ),
                      ),
                    const SizedBox(height: Space.x6),
                    AppButton(
                      label: _holdExpiresAt != null
                          ? l10n.paymentRetryCta(
                              Fmt.money(order.breakdown.total),
                            )
                          : l10n.cartHoldAgain,
                      isLoading: _retrying,
                      onPressed: _retrying ? null : _retry,
                    ),
                    if (_holdExpiresAt != null) ...[
                      const SizedBox(height: Space.x3),
                      AppButton(
                        label: l10n.paymentTryAnotherMethod,
                        variant: AppButtonVariant.secondary,
                        onPressed: () =>
                            CheckoutPayRoute(holdId: order.holdId).go(context),
                      ),
                    ],
                    const SizedBox(height: Space.x3),
                    AppButton(
                      label: l10n.back,
                      variant: AppButtonVariant.tertiary,
                      onPressed: () => const DiscoverRoute().go(context),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
