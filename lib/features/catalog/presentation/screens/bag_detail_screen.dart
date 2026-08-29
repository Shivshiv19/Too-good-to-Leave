import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:surplus_marketplace/app/router/routes.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/domain/lat_lng.dart';
import 'package:surplus_marketplace/core/domain/pickup_window.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/core/utils/formatters.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/components/countdown_text.dart';
import 'package:surplus_marketplace/design_system/components/dietary_mark_chip.dart';
import 'package:surplus_marketplace/design_system/components/floating_icon_button.dart';
import 'package:surplus_marketplace/design_system/components/icon_badge.dart';
import 'package:surplus_marketplace/design_system/components/quantity_stepper.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/bag_status.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/merchant.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/offer.dart';
import 'package:surplus_marketplace/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:surplus_marketplace/features/catalog/presentation/utils/dietary_label.dart';
import 'package:surplus_marketplace/features/location/presentation/providers/location_providers.dart';

enum _Phase { loading, loaded, notFound, error }

/// §4.2 `/discover/bag/:bagId`, §5b.9 — "the hardest screen in the
/// product": creating enough certainty about a deliberately undisclosed
/// product to justify prepayment.
class BagDetailScreen extends ConsumerStatefulWidget {
  const BagDetailScreen({required this.bagId, super.key});

  final String bagId;

  @override
  ConsumerState<BagDetailScreen> createState() => _BagDetailScreenState();
}

class _BagDetailScreenState extends ConsumerState<BagDetailScreen> {
  static const _clock = SystemClock();

  _Phase _phase = _Phase.loading;
  SurpriseBag? _bag;
  Merchant? _merchant;
  int _distanceMetres = 0;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _phase = _Phase.loading);
    try {
      final repo = ref.read(catalogRepositoryProvider);
      // Always a fresh fetch, never the discover-list cache — A8's exact
      // quantityAvailable and A9's remainingAllowanceForCustomer only ever
      // come from here.
      final bag = await repo.bag(widget.bagId);
      final merchant = await repo.merchant(bag.merchantId);
      final cached = await ref
          .read(locationRepositoryProvider)
          .cachedLocation();
      final anchor =
          cached?.latLng ?? const LatLng(latitude: 12.9716, longitude: 77.5946);
      if (!mounted) return;
      setState(() {
        _bag = bag;
        _merchant = merchant;
        _distanceMetres = anchor
            .distanceInMetersTo(merchant.address.geo)
            .round();
        _quantity = 1;
        _phase = _Phase.loaded;
      });
    } on Object {
      if (mounted) setState(() => _phase = _Phase.notFound);
    }
  }

  void _reserve() {
    CheckoutRoute(bagId: widget.bagId, quantity: _quantity).go(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    if (_phase == _Phase.loading) {
      return Scaffold(
        backgroundColor: colors.surfaceBase,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_phase == _Phase.notFound || _phase == _Phase.error) {
      return Scaffold(
        backgroundColor: colors.surfaceBase,
        appBar: AppBar(backgroundColor: colors.surfaceBase, elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.x6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.notFoundTitle, style: context.type.title),
                const SizedBox(height: Space.x2),
                Text(
                  l10n.notFoundBody,
                  style: context.type.body.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bag = _bag!;
    final merchant = _merchant!;
    final isTerminal =
        bag.status != BagStatus.live || bag.quantityAvailable == 0;
    // The shop editor's Quantity field and its Draft/Live/Paused toggle are
    // independent controls, so a bag can be `live` with 0 units left
    // without the shop ever having touched its status. Sold-out copy is
    // the honest reason in that case, not the raw (still-`live`) status.
    final effectiveStatus =
        bag.quantityAvailable == 0 && bag.status == BagStatus.live
        ? BagStatus.soldOut
        : bag.status;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.only(
                bottom: Layout.stickyActionBarHeight + Space.x6,
              ),
              children: [
                Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: bag.imageUrl,
                      height: 240,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(height: 240, color: colors.surfaceSunken),
                      errorWidget: (context, url, error) =>
                          Container(height: 240, color: colors.surfaceSunken),
                    ),
                    Positioned(
                      left: Space.x2,
                      top: Space.x2,
                      child: FloatingIconButton(
                        icon: Icons.arrow_back,
                        semanticLabel: l10n.back,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                    if (merchant.ratingAggregate.hasReviews)
                      Positioned(
                        left: Space.x2,
                        bottom: Space.x2,
                        child: ExcludeSemantics(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Space.x2,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceRaised.withValues(
                                alpha: 0.92,
                              ),
                              borderRadius: BorderRadius.circular(Radii.full),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 14,
                                  color: colors.actionPrimaryBg,
                                ),
                                const SizedBox(width: Space.x1),
                                Text(
                                  '${merchant.ratingAggregate.average.toStringAsFixed(1)} '
                                  '(${merchant.ratingAggregate.count})',
                                  style: context.type.caption.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (!isTerminal)
                      Positioned(
                        right: Space.x2,
                        bottom: Space.x2,
                        child: ExcludeSemantics(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Space.x3,
                              vertical: Space.x1,
                            ),
                            decoration: BoxDecoration(
                              color: colors.actionPrimaryBg,
                              borderRadius: BorderRadius.circular(Radii.full),
                            ),
                            child: Text(
                              'Pickup ${Fmt.pickupWindowCompact(bag.pickupWindow)}',
                              style: context.type.caption.copyWith(
                                color: colors.actionPrimaryFg,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(Space.x4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.bagImageRepresentative,
                        style: context.type.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: Space.x4),
                      Text(bag.title, style: context.type.display),
                      const SizedBox(height: Space.x1),
                      GestureDetector(
                        onTap: () => DiscoverMerchantRoute(
                          merchantId: merchant.id,
                        ).push<void>(context),
                        child: Text(
                          merchant.displayName,
                          style: context.type.body.copyWith(
                            color: colors.actionSecondaryFg,
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.x4),
                      // Early in the semantic order (§5b.9 accessibility
                      // requirement) — a screen-reader user must not
                      // traverse price/description/location first to learn
                      // whether they're permitted to eat this.
                      DietaryMarkChip(
                        envelope: bag.dietaryEnvelope,
                        label: dietaryEnvelopeLabel(bag.dietaryEnvelope, l10n),
                      ),
                      const SizedBox(height: Space.x4),
                      if (isTerminal)
                        _TerminalStateBanner(
                          status: effectiveStatus,
                          l10n: l10n,
                        )
                      else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(Space.x4),
                          decoration: BoxDecoration(
                            color: colors.surfaceSunken,
                            borderRadius: BorderRadius.circular(Radii.card),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.bagValueBreakdownLabel,
                                style: context.type.label.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: Space.x3),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    l10n.bagOriginalValueLabel,
                                    style: context.type.body.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    Fmt.money(bag.statedRetailValue),
                                    semanticsLabel: Fmt.wasPriceSemantics(
                                      bag.statedRetailValue,
                                    ),
                                    style: context.type.body.copyWith(
                                      color: colors.textTertiary,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: Space.x2),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    l10n.bagRescuePriceLabel,
                                    style: context.type.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        Fmt.money(bag.price),
                                        style: context.type.priceMedium
                                            .copyWith(
                                              color: colors.actionPrimaryBg,
                                            ),
                                      ),
                                      const SizedBox(width: Space.x2),
                                      Text(
                                        l10n.bagDiscountBadge(
                                          bag.discountPercent,
                                        ),
                                        style: context.type.caption.copyWith(
                                          color: colors.success.fg,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Space.x2),
                        Text(
                          l10n.bagScarcityExact(bag.quantityAvailable),
                          style: context.type.body.copyWith(
                            color: colors.critical.fg,
                          ),
                        ),
                      ],
                      const SizedBox(height: Space.x6),
                      Text(
                        l10n.bagDetailWhatToExpectLabel,
                        style: context.type.label.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: Space.x1),
                      Text(bag.categoryHint, style: context.type.body),
                      if (bag.allergenNotes != null) ...[
                        const SizedBox(height: Space.x4),
                        Text(
                          l10n.bagDetailAllergenLabel,
                          style: context.type.label.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: Space.x1),
                        Text(bag.allergenNotes!, style: context.type.body),
                      ],
                      const SizedBox(height: Space.x6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const IconBadge(icon: Icons.schedule),
                          const SizedBox(width: Space.x3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  Fmt.pickupWindow(bag.pickupWindow, _clock),
                                  style: context.type.body,
                                ),
                                if (bag.pickupWindow.urgencyAt(_clock) ==
                                    WindowUrgency.closingSoon)
                                  CountdownText(
                                    target: bag.pickupWindow.endAt,
                                    clock: _clock,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.x4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const IconBadge(icon: Icons.place_outlined),
                          const SizedBox(width: Space.x3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  merchant.address.displayLine,
                                  style: context.type.body,
                                ),
                                Text(
                                  '${Fmt.distance(_distanceMetres)} away',
                                  style: context.type.caption.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.x2),
                      AppButton(
                        label: l10n.pickupDirections(merchant.displayName),
                        variant: AppButtonVariant.tertiary,
                        icon: Icons.directions_outlined,
                        expand: false,
                        onPressed: () {},
                      ),
                      const SizedBox(height: Space.x6),
                      Text(
                        l10n.bagDetailPickupInstructionsLabel,
                        style: context.type.label.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: Space.x1),
                      Text(bag.pickupInstructions, style: context.type.body),
                      const SizedBox(height: Space.x1),
                      Text(
                        l10n.bagBringOwnBag,
                        style: context.type.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!isTerminal)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _StickyReserveBar(
                  bag: bag,
                  quantity: _quantity,
                  onQuantityChanged: (q) => setState(() => _quantity = q),
                  onReserve: _reserve,
                  l10n: l10n,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TerminalStateBanner extends StatelessWidget {
  const _TerminalStateBanner({required this.status, required this.l10n});

  final BagStatus status;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (title, body) = switch (status) {
      BagStatus.soldOut => (l10n.bagSoldOutTitle, l10n.bagSoldOutBody),
      BagStatus.withdrawnByMerchant => (
        l10n.bagWithdrawnTitle,
        l10n.bagWithdrawnBody,
      ),
      _ => (l10n.bagWindowClosedTitle, l10n.bagWindowClosedBody),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.x4),
      decoration: BoxDecoration(
        color: colors.critical.bg,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.type.title.copyWith(color: colors.critical.fg),
          ),
          const SizedBox(height: Space.x1),
          Text(
            body,
            style: context.type.body.copyWith(color: colors.critical.fg),
          ),
        ],
      ),
    );
  }
}

class _StickyReserveBar extends StatelessWidget {
  const _StickyReserveBar({
    required this.bag,
    required this.quantity,
    required this.onQuantityChanged,
    required this.onReserve,
    required this.l10n,
  });

  final SurpriseBag bag;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onReserve;
  final AppLocalizations l10n;

  int get _cap => bag.quantityAvailable;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: EdgeInsets.only(
        left: Space.x4,
        right: Space.x4,
        top: Space.x3,
        bottom: Space.x3 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border(top: BorderSide(color: colors.borderSubtle)),
      ),
      child: Row(
        children: [
          QuantityStepper(
            value: quantity,
            onChanged: onQuantityChanged,
            max: _cap,
            decreaseLabel: l10n.cartQuantityDecrease,
            increaseLabel: l10n.cartQuantityIncrease,
          ),
          const SizedBox(width: Space.x3),
          Expanded(
            // Per-bag price only, never scaled by [quantity] here (R1 —
            // money arithmetic, including a simple quantity multiply, is
            // legal only inside `core/domain`/fake repositories, never
            // presentation code). A real cart total is the server's job
            // once `checkout` exists.
            child: AppButton(
              label: l10n.bagReserveCta(Fmt.money(bag.price)),
              onPressed: onReserve,
            ),
          ),
        ],
      ),
    );
  }
}
