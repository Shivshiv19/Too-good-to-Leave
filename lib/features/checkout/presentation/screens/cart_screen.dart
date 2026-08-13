import 'dart:async';

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
import 'package:surplus_marketplace/design_system/components/dietary_mark_chip.dart';
import 'package:surplus_marketplace/design_system/components/hold_countdown_banner.dart';
import 'package:surplus_marketplace/design_system/components/price_breakdown_list.dart';
import 'package:surplus_marketplace/design_system/components/quantity_stepper.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/offer.dart';
import 'package:surplus_marketplace/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:surplus_marketplace/features/catalog/presentation/utils/dietary_label.dart';
import 'package:surplus_marketplace/features/checkout/domain/entities/hold.dart';
import 'package:surplus_marketplace/features/checkout/presentation/providers/checkout_providers.dart';

enum _Phase { creatingHold, holdActive, requoting, holdExpired, error }

/// §4.2 `/checkout?bagId=<id>`, §5c.1 — "Your reservation". Confirms what
/// is being reserved, shows the true all-inclusive price (R1), and starts
/// the hold clock.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({required this.bagId, required this.quantity, super.key});

  final String bagId;
  final int quantity;

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  static const _clock = SystemClock();

  _Phase _phase = _Phase.creatingHold;
  Hold? _hold;
  SurpriseBag? _bag;
  Timer? _debounce;
  late int _quantity;

  @override
  void initState() {
    super.initState();
    _quantity = widget.quantity;
    _createHold();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _createHold() async {
    setState(() => _phase = _Phase.creatingHold);
    try {
      final bag = await ref.read(catalogRepositoryProvider).bag(widget.bagId);
      final hold = await ref
          .read(checkoutRepositoryProvider)
          .createHold(bagId: widget.bagId, quantity: _quantity);
      if (!mounted) return;
      setState(() {
        _bag = bag;
        _hold = hold;
        _phase = _Phase.holdActive;
      });
    } on Object catch (error) {
      _handleError(error);
    }
  }

  void _handleError(Object error) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (error is DomainConflictException) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_domainConflictMessage(error, l10n))),
      );
      context.pop();
      return;
    }
    setState(() => _phase = _Phase.error);
  }

  String _domainConflictMessage(
    DomainConflictException error,
    AppLocalizations l10n,
  ) => switch (error) {
    BagSoldOutException() => l10n.bagSoldOutBody,
    BagWithdrawnException() => l10n.bagWithdrawnBody,
    BagWindowClosedException() => l10n.bagWindowClosedBody,
    final PurchaseCapExceededException e => l10n.purchaseCapBody(
      e.remainingAllowance,
    ),
    _ => l10n.errorServerBody,
  };

  void _onQuantityChanged(int next) {
    final hold = _hold;
    if (hold == null || next < 1) return;
    setState(() {
      _quantity = next;
      _phase = _Phase.requoting;
    });
    _debounce?.cancel();
    // A11 — debounced re-quote; no locally-computed total is ever shown,
    // not even optimistically.
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _requote(hold.id),
    );
  }

  Future<void> _requote(String holdId) async {
    try {
      final adjusted = await ref
          .read(checkoutRepositoryProvider)
          .adjustHold(holdId: holdId, quantity: _quantity);
      if (!mounted) return;
      setState(() {
        _hold = adjusted;
        _phase = _Phase.holdActive;
      });
    } on Object catch (error) {
      _handleError(error);
    }
  }

  void _onExpired() {
    if (mounted) setState(() => _phase = _Phase.holdExpired);
  }

  Future<void> _holdAgain() async {
    await _createHold();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        elevation: 0,
        title: Text(l10n.cartTitle, style: context.type.title),
      ),
      body: SafeArea(child: _buildBody(context, l10n)),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    final colors = context.colors;
    switch (_phase) {
      case _Phase.creatingHold:
        return const Center(child: CircularProgressIndicator());
      case _Phase.error:
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
                  style: context.type.body.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.x4),
                AppButton(label: l10n.retryCta, onPressed: _createHold),
              ],
            ),
          ),
        );
      case _Phase.holdExpired:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.x6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.cartHoldExpiredTitle, style: context.type.title),
                const SizedBox(height: Space.x2),
                Text(
                  l10n.cartHoldExpiredBody(9),
                  style: context.type.body.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.x4),
                AppButton(label: l10n.cartHoldAgain, onPressed: _holdAgain),
              ],
            ),
          ),
        );
      case _Phase.holdActive:
      case _Phase.requoting:
        return _buildActive(context, l10n);
    }
  }

  Widget _buildActive(BuildContext context, AppLocalizations l10n) {
    final hold = _hold!;
    final bag = _bag!;

    return ListView(
      padding: const EdgeInsets.all(Space.x4),
      children: [
        HoldCountdownBanner(
          expiresAt: hold.expiresAt,
          clock: _clock,
          label: l10n.cartHoldBanner,
          onExpired: _onExpired,
        ),
        const SizedBox(height: Space.x4),
        Text(bag.title, style: context.type.title),
        const SizedBox(height: Space.x1),
        DietaryMarkChip(
          envelope: bag.dietaryEnvelope,
          label: dietaryEnvelopeLabel(bag.dietaryEnvelope, l10n),
          compact: true,
        ),
        const SizedBox(height: Space.x4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(Fmt.money(bag.price), style: context.type.body),
            QuantityStepper(
              value: _quantity,
              onChanged: _onQuantityChanged,
              max: bag.quantityAvailable,
              decreaseLabel: l10n.cartQuantityDecrease,
              increaseLabel: l10n.cartQuantityIncrease,
            ),
          ],
        ),
        const SizedBox(height: Space.x4),
        Text(
          Fmt.pickupWindow(bag.pickupWindow, _clock),
          style: context.type.body,
        ),
        const SizedBox(height: Space.x6),
        PriceBreakdownList(
          breakdown: hold.breakdown,
          isRequoting: _phase == _Phase.requoting,
        ),
        const SizedBox(height: Space.x6),
        AppButton(
          label: l10n.cartContinueCta,
          onPressed: _phase == _Phase.requoting
              ? null
              : () => CheckoutPayRoute(holdId: hold.id).go(context),
        ),
      ],
    );
  }
}
