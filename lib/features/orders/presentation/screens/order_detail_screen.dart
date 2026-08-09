import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:surplus_marketplace/app/router/routes.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/core/utils/formatters.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/components/dietary_mark_chip.dart';
import 'package:surplus_marketplace/design_system/components/legal_disclosure_block.dart';
import 'package:surplus_marketplace/design_system/components/order_status_chip.dart';
import 'package:surplus_marketplace/design_system/components/price_breakdown_list.dart';
import 'package:surplus_marketplace/design_system/components/refund_timeline.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/checkout/checkout.dart';
import 'package:surplus_marketplace/features/orders/orders.dart';
import 'package:surplus_marketplace/features/orders/presentation/dialogs/cancel_order_dialog.dart';
import 'package:surplus_marketplace/features/orders/presentation/utils/dietary_label.dart';
import 'package:surplus_marketplace/features/orders/presentation/utils/directions_launcher.dart';
import 'package:surplus_marketplace/features/orders/presentation/utils/order_status_label.dart';
import 'package:surplus_marketplace/features/orders/presentation/utils/payment_method_label.dart';

enum _Phase { loading, loaded, notFound, error }

/// Whether [status] belongs to the linear reserve → ready → collect
/// progression the stepper below can represent. Terminal/failure branches
/// (cancelled, expired, payment failed) don't fit a straight line and stay
/// on [_StatusBanner]/[OrderStatusChip] alone.
bool _isHappyPathStatus(OrderStatus status) =>
    status == OrderStatus.confirmed ||
    status == OrderStatus.readyForPickup ||
    status == OrderStatus.collected;

List<RefundTimelineStep> _orderProgressSteps(
  OrderStatus status,
  AppLocalizations l10n,
) {
  final readyDone =
      status == OrderStatus.readyForPickup || status == OrderStatus.collected;
  final collectedDone = status == OrderStatus.collected;
  return [
    RefundTimelineStep(label: l10n.orderStatusConfirmed, completed: true),
    RefundTimelineStep(
      label: l10n.orderStatusReadyForPickup,
      completed: readyDone,
    ),
    RefundTimelineStep(
      label: l10n.pickupCollectedTitle,
      completed: collectedDone,
    ),
  ];
}

/// §4.2 `/orders/:orderId`, §5d.2 — the receipt, and the single source of
/// truth for one order.
class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  static const _clock = SystemClock();

  _Phase _phase = _Phase.loading;
  Order? _order;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _phase = _Phase.loading);
    try {
      final order = await ref
          .read(ordersRepositoryProvider)
          .getOrder(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _phase = _Phase.loaded;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _announceBanner());
    } on NotFoundException {
      if (mounted) setState(() => _phase = _Phase.notFound);
    } on Object {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  void _announceBanner() {
    final order = _order;
    if (order == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    SemanticsService.announce(
      orderStatusLabel(order.status, l10n),
      Directionality.of(context),
      assertiveness: Assertiveness.assertive,
    );
  }

  Future<void> _shareReceipt(Order order, AppLocalizations l10n) async {
    final lines = [
      '${l10n.confirmedOrderCode}: ${order.orderCode}',
      order.bagSnapshot.title,
      order.merchantSnapshot.displayName,
      Fmt.pickupWindow(order.pickupWindow, _clock),
      '${l10n.priceTotal}: ${Fmt.money(order.breakdown.total)}',
    ];
    try {
      // The replacement (SharePlus.instance.share) needs a ShareParams
      // object; share() is the simpler call for this plain-text case and
      // remains supported (same precedent as `ConfirmedScreen`).
      // ignore: deprecated_member_use
      await Share.share(lines.join('\n'));
    } on Object {
      // Best-effort — never blocks the receipt from being viewed.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(backgroundColor: colors.surfaceBase, elevation: 0),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.loading => const Center(child: CircularProgressIndicator()),
          _Phase.notFound => _NotFound(l10n: l10n),
          _Phase.error => _ErrorState(onRetry: _load, l10n: l10n),
          _Phase.loaded => _Detail(
            order: _order!,
            clock: _clock,
            l10n: l10n,
            onShare: () => _shareReceipt(_order!, l10n),
            onReload: _load,
          ),
        },
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({
    required this.order,
    required this.clock,
    required this.l10n,
    required this.onShare,
    required this.onReload,
  });

  final Order order;
  final Clock clock;
  final AppLocalizations l10n;
  final VoidCallback onShare;
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsets.all(Space.x4),
      children: [
        _StatusBanner(order: order, l10n: l10n),
        if (_isHappyPathStatus(order.status)) ...[
          const SizedBox(height: Space.x4),
          RefundTimeline(
            steps: _orderProgressSteps(order.status, l10n),
            semanticLabelFor: (step, index) => step.label,
          ),
        ],
        const SizedBox(height: Space.x4),
        Text(order.orderCode, style: context.type.title),
        const SizedBox(height: Space.x4),
        Container(
          padding: const EdgeInsets.all(Space.x4),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(order.bagSnapshot.title, style: context.type.title),
              const SizedBox(height: Space.x1),
              DietaryMarkChip(
                envelope: order.bagSnapshot.dietaryEnvelope,
                label: dietaryEnvelopeLabel(
                  order.bagSnapshot.dietaryEnvelope,
                  l10n,
                ),
                compact: true,
              ),
              const SizedBox(height: Space.x1),
              Text(
                'x${order.quantity}',
                style: context.type.body.copyWith(color: colors.textSecondary),
              ),
              const Divider(height: Space.x6),
              Text(
                order.merchantSnapshot.displayName,
                style: context.type.body,
              ),
              Text(
                order.merchantSnapshot.address.displayLine,
                style: context.type.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              Text(
                order.merchantSnapshot.phone,
                style: context.type.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const Divider(height: Space.x6),
              Text(
                Fmt.pickupWindow(order.pickupWindow, clock),
                style: context.type.body,
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.x4),
        PriceBreakdownList(breakdown: order.breakdown),
        const SizedBox(height: Space.x4),
        Text(
          l10n.orderDetailPaymentMethod,
          style: context.type.caption.copyWith(color: colors.textSecondary),
        ),
        Text(
          l10n.orderPaymentMasked(
            paymentMethodLabel(order.payment.method, l10n),
            order.payment.maskedIdentifier ?? '----',
          ),
          style: context.type.body,
        ),
        const SizedBox(height: Space.x6),
        LegalDisclosureBlock(
          legalName: order.merchantSnapshot.legalName,
          fssaiLine:
              '${l10n.merchantFssaiLabel}: ${order.merchantSnapshot.fssaiLicenceNumber}',
          fssaiValidUntilLine: l10n.merchantFssaiValidUntil(
            Fmt.expectedBy(order.merchantSnapshot.fssaiLicenceExpiry),
          ),
          grievanceLine:
              '${l10n.merchantGrievanceLabel}: ${order.merchantSnapshot.grievanceContact}',
        ),
        const SizedBox(height: Space.x4),
        AppButton(
          label: l10n.orderDetailShareReceipt,
          variant: AppButtonVariant.secondary,
          icon: Icons.ios_share,
          onPressed: onShare,
        ),
        const SizedBox(height: Space.x6),
        _Actions(order: order, l10n: l10n, onReload: onReload),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.order, required this.l10n});

  final Order order;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (title, body) = switch (order.status) {
      OrderStatus.pendingPayment => (l10n.orderStatusPendingPayment, null),
      OrderStatus.confirmed => (l10n.orderStatusConfirmed, null),
      OrderStatus.paymentFailed => (l10n.paymentFailedTitle, null),
      OrderStatus.readyForPickup => (l10n.orderStatusReadyForPickup, null),
      OrderStatus.collected => (
        l10n.pickupCollectedTitle,
        l10n.pickupCollectedBody,
      ),
      OrderStatus.cancelledByCustomer => (
        l10n.orderStatusCancelledByCustomer,
        order.cancellationReason,
      ),
      OrderStatus.cancelledByMerchant => (
        l10n.merchantCancelledTitle,
        l10n.merchantCancelledBody(
          order.merchantSnapshot.displayName,
          Fmt.money(order.breakdown.total),
        ),
      ),
      OrderStatus.expiredUncollected => (
        l10n.orderExpiredTitle,
        l10n.orderExpiredBody(Fmt.timeOfDay(order.pickupWindow.endAt)),
      ),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.type.title),
                if (body != null)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.x1),
                    child: Text(
                      body,
                      style: context.type.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          OrderStatusChip(
            status: order.status,
            label: orderStatusLabel(order.status, l10n),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.order,
    required this.l10n,
    required this.onReload,
  });

  final Order order;
  final AppLocalizations l10n;
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];

    switch (order.status) {
      case OrderStatus.pendingPayment:
        buttons.add(
          AppButton(
            label: l10n.orderActionCompletePayment,
            onPressed: () =>
                CheckoutVerifyingRoute(orderId: order.id).go(context),
          ),
        );
      case OrderStatus.paymentFailed:
        buttons.add(
          AppButton(
            label: l10n.paymentRetryCta(Fmt.money(order.breakdown.total)),
            onPressed: () => CheckoutFailedRoute(orderId: order.id).go(context),
          ),
        );
      case OrderStatus.confirmed:
      case OrderStatus.readyForPickup:
        buttons
          ..add(
            AppButton(
              label: l10n.orderActionShowPickupCode,
              onPressed: () =>
                  OrderPickupRoute(orderId: order.id).push<void>(context),
            ),
          )
          ..add(const SizedBox(height: Space.x3))
          ..add(
            AppButton(
              label: l10n.pickupDirections(order.merchantSnapshot.displayName),
              variant: AppButtonVariant.secondary,
              onPressed: () => openDirections(
                order.merchantSnapshot.address.geo.latitude,
                order.merchantSnapshot.address.geo.longitude,
              ),
            ),
          )
          ..add(const SizedBox(height: Space.x3))
          ..add(
            AppButton(
              label: l10n.orderActionCancel,
              variant: AppButtonVariant.secondary,
              onPressed: () async {
                final cancelled = await showCancelOrderDialog(
                  context,
                  orderId: order.id,
                );
                if (cancelled) await onReload();
              },
            ),
          );
      case OrderStatus.collected:
      case OrderStatus.expiredUncollected:
        break;
      case OrderStatus.cancelledByCustomer:
      case OrderStatus.cancelledByMerchant:
        buttons.add(
          AppButton(
            label: l10n.orderActionViewRefund,
            onPressed: () =>
                OrderRefundRoute(orderId: order.id).push<void>(context),
          ),
        );
    }

    if (order.status == OrderStatus.confirmed ||
        order.status == OrderStatus.readyForPickup ||
        order.status == OrderStatus.collected ||
        order.status == OrderStatus.expiredUncollected) {
      if (buttons.isNotEmpty) buttons.add(const SizedBox(height: Space.x3));
      buttons.add(
        AppButton(
          label: l10n.orderActionReportIssue,
          variant: AppButtonVariant.tertiary,
          onPressed: () =>
              OrderIssueRoute(orderId: order.id).push<void>(context),
        ),
      );
    }

    return Column(children: buttons);
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: colors.textTertiary),
            const SizedBox(height: Space.x4),
            Text(
              l10n.notFoundTitle,
              style: context.type.display,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.x2),
            Text(
              l10n.notFoundBody,
              style: context.type.body.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.x6),
            AppButton(
              label: l10n.back,
              onPressed: () => const OrdersRoute().go(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry, required this.l10n});

  final Future<void> Function() onRetry;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: colors.textTertiary),
            const SizedBox(height: Space.x4),
            Text(
              l10n.errorServerTitle,
              style: context.type.display,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.x2),
            Text(
              l10n.errorServerBody,
              style: context.type.body.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.x6),
            AppButton(label: l10n.errorRetry, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
