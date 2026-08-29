import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:surplus_marketplace/app/router/routes.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/core/utils/formatters.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/components/hold_countdown_banner.dart';
import 'package:surplus_marketplace/design_system/components/price_breakdown_list.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/auth/presentation/providers/auth_providers.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/merchant.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/offer.dart';
import 'package:surplus_marketplace/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:surplus_marketplace/features/checkout/domain/entities/hold.dart';
import 'package:surplus_marketplace/features/checkout/domain/entities/payment_method.dart';
import 'package:surplus_marketplace/features/checkout/presentation/providers/checkout_providers.dart';
import 'package:surplus_marketplace/features/checkout/presentation/sheets/payment_method_sheet.dart';
import 'package:surplus_marketplace/features/checkout/presentation/sheets/upi_app_chooser_sheet.dart';
import 'package:surplus_marketplace/features/config/presentation/providers/config_providers.dart';

enum _Phase { loading, idle, submitting, error }

/// §4.2 `/checkout/pay`, §5c.2 — final review, method selection, and the
/// binding commitment.
///
/// **D-c4.** No confirmation dialog before payment — the CTA states the
/// amount and the subtext sets the app-switch expectation. A dialog adds a
/// tap without adding comprehension.
class ReviewPayScreen extends ConsumerStatefulWidget {
  const ReviewPayScreen({required this.holdId, super.key});

  final String holdId;

  @override
  ConsumerState<ReviewPayScreen> createState() => _ReviewPayScreenState();
}

class _ReviewPayScreenState extends ConsumerState<ReviewPayScreen> {
  static const _clock = SystemClock();

  _Phase _phase = _Phase.loading;
  Hold? _hold;
  SurpriseBag? _bag;
  Merchant? _merchant;
  DateTime? _cancellationCutoff;
  PaymentMethod _method = PaymentMethod.upi;
  String? _upiApp;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _phase = _Phase.loading);
    try {
      final hold = await ref
          .read(checkoutRepositoryProvider)
          .getHold(widget.holdId);
      final bag = await ref.read(catalogRepositoryProvider).bag(hold.bagId);
      final merchant = await ref
          .read(catalogRepositoryProvider)
          .merchant(bag.merchantId);
      final config = await ref.read(remoteConfigProvider.future);
      if (!mounted) return;
      setState(() {
        _hold = hold;
        _bag = bag;
        _merchant = merchant;
        _cancellationCutoff = bag.pickupWindow.startAt.subtract(
          config.policyValues.cancellationCutoffBeforeWindow,
        );
        _phase = _Phase.idle;
      });
    } on HoldExpiredException {
      final hold = _hold;
      if (mounted && hold != null) {
        CheckoutRoute(bagId: hold.bagId, quantity: hold.quantity).go(context);
      } else if (mounted) {
        context.pop();
      }
    } on Object {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  Future<void> _selectMethod(PaymentMethod method) async {
    setState(() => _method = method);
    if (method == PaymentMethod.upi) await _chooseUpiApp();
  }

  Future<void> _chooseUpiApp() async {
    final result = await showModalBottomSheet<String?>(
      context: context,
      builder: (context) => const UpiAppChooserSheet(),
    );
    if (mounted) setState(() => _upiApp = result);
  }

  Future<void> _pay() async {
    final hold = _hold;
    if (hold == null) return;
    setState(() => _phase = _Phase.submitting);
    try {
      final customer = await ref.read(authRepositoryProvider).restoreSession();
      if (customer == null) {
        // The auth wall (A4) guarantees this shouldn't happen; defensive
        // only.
        if (mounted) setState(() => _phase = _Phase.error);
        return;
      }
      final result = await ref
          .read(checkoutRepositoryProvider)
          .createOrder(
            holdId: hold.id,
            customerId: customer.id,
            method: _method,
            upiApp: _upiApp,
          );
      if (!mounted) return;
      CheckoutProcessingRoute(
        orderId: result.order.id,
        paymentId: result.payment.id,
        gatewayPayload: result.gatewayPayload,
      ).go(context);
    } on HoldExpiredException {
      if (mounted) {
        CheckoutRoute(bagId: hold.bagId, quantity: hold.quantity).go(context);
      }
    } on DomainConflictException {
      final l10n = AppLocalizations.of(context);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.bagSoldOutBody)));
        setState(() => _phase = _Phase.idle);
      }
    } on Object {
      // A reset-to-idle with no message here reads as "the button did
      // nothing" — the worst possible feedback for a payment tap that just
      // hit a real network backend. Always surface *something*.
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.errorServerBody)));
        setState(() => _phase = _Phase.idle);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(backgroundColor: colors.surfaceBase, elevation: 0),
      body: SafeArea(child: _buildBody(context, l10n)),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    final colors = context.colors;
    if (_phase == _Phase.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_phase == _Phase.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.errorServerTitle, style: context.type.title),
              const SizedBox(height: Space.x2),
              Text(
                l10n.errorServerBody,
                style: context.type.body.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: Space.x4),
              AppButton(label: l10n.retryCta, onPressed: _load),
            ],
          ),
        ),
      );
    }

    final hold = _hold!;
    final bag = _bag!;
    final merchant = _merchant!;
    final methods = <(PaymentMethod, String, bool)>[
      (PaymentMethod.upi, l10n.checkoutMethodUpi, true),
      (PaymentMethod.card, l10n.checkoutMethodCard, true),
      (PaymentMethod.netBanking, l10n.checkoutMethodNetBanking, true),
      (PaymentMethod.wallet, l10n.checkoutMethodWallet, false),
    ];

    return ListView(
      padding: const EdgeInsets.all(Space.x4),
      children: [
        HoldCountdownBanner(
          expiresAt: hold.expiresAt,
          clock: _clock,
          label: l10n.cartHoldBanner,
        ),
        const SizedBox(height: Space.x4),
        Text(bag.title, style: context.type.title),
        Text(
          merchant.displayName,
          style: context.type.body.copyWith(color: colors.textSecondary),
        ),
        Text(
          Fmt.pickupWindow(bag.pickupWindow, _clock),
          style: context.type.caption.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: Space.x6),
        Text(l10n.checkoutPaymentMethodLabel, style: context.type.title),
        const SizedBox(height: Space.x3),
        for (final (method, label, available) in methods) ...[
          PaymentMethodOptionRow(
            label: method == PaymentMethod.upi && _upiApp != null
                ? '$label · $_upiApp'
                : label,
            recommended: method == PaymentMethod.upi,
            available: available,
            selected: _method == method,
            colors: colors,
            l10n: l10n,
            onTap: available && _phase != _Phase.submitting
                ? () => _selectMethod(method)
                : null,
          ),
          const SizedBox(height: Space.x2),
        ],
        const SizedBox(height: Space.x4),
        Container(
          padding: const EdgeInsets.all(Space.x4),
          decoration: BoxDecoration(
            color: colors.surfaceSunken,
            borderRadius: BorderRadius.circular(Radii.card),
          ),
          child: PriceBreakdownList(breakdown: hold.breakdown),
        ),
        const SizedBox(height: Space.x6),
        Container(
          padding: const EdgeInsets.all(Space.x3),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.checkoutTermsPickup(
                  Fmt.timeOfDay(bag.pickupWindow.startAt),
                  Fmt.timeOfDay(bag.pickupWindow.endAt),
                  merchant.displayName,
                ),
                style: context.type.caption,
              ),
              const SizedBox(height: Space.x2),
              Text(
                l10n.checkoutTermsNoShow,
                style: context.type.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: Space.x2),
              if (_cancellationCutoff != null)
                Text(
                  l10n.checkoutTermsCancellation(
                    Fmt.expectedBy(_cancellationCutoff!),
                  ),
                  style: context.type.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.x6),
        AppButton(
          label: l10n.checkoutPayCta(Fmt.money(hold.breakdown.total)),
          isLoading: _phase == _Phase.submitting,
          onPressed: _phase == _Phase.submitting ? null : _pay,
        ),
        const SizedBox(height: Space.x2),
        Center(
          child: Text(
            l10n.checkoutPaySubtext,
            style: context.type.caption.copyWith(color: colors.textSecondary),
          ),
        ),
      ],
    );
  }
}
