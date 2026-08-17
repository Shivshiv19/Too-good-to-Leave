import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:surplus_marketplace/app/router/routes.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/core/utils/formatters.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/components/hero_pickup_card.dart';
import 'package:surplus_marketplace/design_system/components/order_status_chip.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/auth/auth.dart';
import 'package:surplus_marketplace/features/checkout/checkout.dart';
import 'package:surplus_marketplace/features/orders/orders.dart';
import 'package:surplus_marketplace/features/orders/presentation/utils/directions_launcher.dart';
import 'package:surplus_marketplace/features/orders/presentation/utils/order_status_label.dart';
import 'package:surplus_marketplace/features/orders/presentation/utils/window_state_label.dart';

enum _Phase { loading, loaded, error }

/// §4.2 `/orders`, §5d.1. Active and Past are segments of one route, not two
/// — they share the card, the refresh machinery, and the status vocabulary.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  static const _clock = SystemClock();

  _Phase _phase = _Phase.loading;
  List<Order> _active = const [];
  List<Order> _past = const [];
  int _segment = 0; // 0 = active, 1 = past

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Only the very first load shows the full-screen spinner. A refresh
    // triggered by returning from an order's detail/pickup screen updates
    // the list quietly instead — the list was already rendered correctly a
    // moment ago, so replacing it with a spinner on every return would be a
    // visible regression for the common case where nothing changed.
    if (_phase != _Phase.loaded) setState(() => _phase = _Phase.loading);
    try {
      final customer = await ref.read(authRepositoryProvider).restoreSession();
      if (customer == null) throw StateError('no session');
      final repo = ref.read(ordersRepositoryProvider);
      final active = await repo.getOrders(
        segment: OrderListSegment.active,
        customerId: customer.id,
      );
      final past = await repo.getOrders(
        segment: OrderListSegment.past,
        customerId: customer.id,
      );
      if (!mounted) return;
      setState(() {
        _active = active;
        _past = past;
        _phase = _Phase.loaded;
      });
    } on Object {
      if (mounted) setState(() => _phase = _Phase.error);
    }
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
        title: Text(l10n.ordersTitle),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: l10n.notificationsTitle,
            onPressed: () => const NotificationsRoute().push<void>(context),
          ),
        ],
      ),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.loading => const Center(child: CircularProgressIndicator()),
          _Phase.error => _ErrorState(onRetry: _load, l10n: l10n),
          _Phase.loaded =>
            _active.isEmpty && _past.isEmpty
                ? _EmptyBoth(l10n: l10n)
                : _Loaded(
                    active: _active,
                    past: _past,
                    segment: _segment,
                    onSegmentChanged: (v) => setState(() => _segment = v),
                    clock: _clock,
                    l10n: l10n,
                    onReturn: _load,
                  ),
        },
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({
    required this.active,
    required this.past,
    required this.segment,
    required this.onSegmentChanged,
    required this.clock,
    required this.l10n,
    required this.onReturn,
  });

  final List<Order> active;
  final List<Order> past;
  final int segment;
  final ValueChanged<int> onSegmentChanged;
  final Clock clock;
  final AppLocalizations l10n;

  /// Refetches active/past from scratch — called after returning from
  /// either order-detail push below. Neither push is a dead end: a pickup
  /// can complete (or a shop can cancel) while that screen is open, and an
  /// order that was Active when this list last loaded may need to be in
  /// Past by the time the user comes back to it.
  final Future<void> Function() onReturn;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(Space.x4),
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 0, label: Text(l10n.ordersSegmentActive)),
              ButtonSegment(value: 1, label: Text(l10n.ordersSegmentPast)),
            ],
            selected: {segment},
            onSelectionChanged: (s) => onSegmentChanged(s.first),
          ),
        ),
        Expanded(
          child: segment == 0
              ? (active.isEmpty
                    ? _EmptyActive(l10n: l10n)
                    : _ActiveList(
                        orders: active,
                        clock: clock,
                        l10n: l10n,
                        onReturn: onReturn,
                      ))
              : (past.isEmpty
                    ? _EmptyPast(l10n: l10n)
                    : _PastList(
                        orders: past,
                        clock: clock,
                        l10n: l10n,
                        onReturn: onReturn,
                      )),
        ),
      ],
    );
  }
}

class _ActiveList extends StatelessWidget {
  const _ActiveList({
    required this.orders,
    required this.clock,
    required this.l10n,
    required this.onReturn,
  });

  final List<Order> orders;
  final Clock clock;
  final AppLocalizations l10n;
  final Future<void> Function() onReturn;

  @override
  Widget build(BuildContext context) {
    final hero = orders.first;
    final rest = orders.skip(1).toList();
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Space.x4),
      children: [
        HeroPickupCard(
          merchantName: hero.merchantSnapshot.displayName,
          bagTitle: hero.bagSnapshot.title,
          thumbnailUrl: hero.bagSnapshot.imageUrl,
          pickupWindow: hero.pickupWindow,
          clock: clock,
          stateLabel: windowStateLabel(hero.pickupWindow, clock, l10n),
          onShowCode: () async {
            await OrderPickupRoute(orderId: hero.id).push<void>(context);
            await onReturn();
          },
          onDirections: () => openDirections(
            hero.merchantSnapshot.address.geo.latitude,
            hero.merchantSnapshot.address.geo.longitude,
          ),
          semanticLabel: l10n.orderCardSemantic(
            hero.orderCode,
            hero.bagSnapshot.title,
            hero.merchantSnapshot.displayName,
            windowStateLabel(hero.pickupWindow, clock, l10n),
          ),
          showCodeLabel: l10n.orderActionShowPickupCode,
          showCodeSemanticLabel: l10n.ordersShowCodeSemantic(hero.orderCode),
          directionsLabel: l10n.pickupDirections(
            hero.merchantSnapshot.displayName,
          ),
        ),
        for (final order in rest) ...[
          const SizedBox(height: Space.listGap),
          _OrderRow(
            order: order,
            clock: clock,
            l10n: l10n,
            onReturn: onReturn,
          ),
        ],
        const SizedBox(height: Space.x6),
      ],
    );
  }
}

class _PastList extends StatelessWidget {
  const _PastList({
    required this.orders,
    required this.clock,
    required this.l10n,
    required this.onReturn,
  });

  final List<Order> orders;
  final Clock clock;
  final AppLocalizations l10n;
  final Future<void> Function() onReturn;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.x4,
        vertical: Space.x2,
      ),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: Space.listGap),
      itemBuilder: (context, i) => _OrderRow(
        order: orders[i],
        clock: clock,
        l10n: l10n,
        onReturn: onReturn,
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({
    required this.order,
    required this.clock,
    required this.l10n,
    required this.onReturn,
  });

  final Order order;
  final Clock clock;
  final AppLocalizations l10n;
  final Future<void> Function() onReturn;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final windowState = windowStateLabel(order.pickupWindow, clock, l10n);
    final statusLabel = orderStatusLabel(order.status, l10n);
    return Semantics(
      button: true,
      label: l10n.orderCardSemantic(
        order.orderCode,
        order.bagSnapshot.title,
        order.merchantSnapshot.displayName,
        windowState,
      ),
      excludeSemantics: true,
      child: Material(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.card),
          onTap: () async {
            await OrderDetailRoute(orderId: order.id).push<void>(context);
            await onReturn();
          },
          child: Container(
            padding: const EdgeInsets.all(Space.x3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.merchantSnapshot.displayName,
                        style: context.type.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        order.bagSnapshot.title,
                        style: context.type.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: Space.x1),
                      Text(
                        Fmt.pickupWindow(order.pickupWindow, clock),
                        style: context.type.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.x2),
                OrderStatusChip(status: order.status, label: statusLabel),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyActive extends StatelessWidget {
  const _EmptyActive({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => _EmptyScaffold(
    icon: Icons.local_dining_outlined,
    title: l10n.ordersEmptyActiveTitle,
    l10n: l10n,
  );
}

class _EmptyPast extends StatelessWidget {
  const _EmptyPast({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => _EmptyScaffold(
    icon: Icons.history,
    title: l10n.ordersEmptyPastTitle,
    l10n: l10n,
    showCta: false,
  );
}

class _EmptyBoth extends StatelessWidget {
  const _EmptyBoth({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: _EmptyScaffold(
        icon: Icons.local_dining_outlined,
        title: l10n.ordersEmptyBothTitle,
        body: l10n.ordersEmptyBothBody,
        l10n: l10n,
      ),
    ),
  );
}

class _EmptyScaffold extends StatelessWidget {
  const _EmptyScaffold({
    required this.icon,
    required this.title,
    required this.l10n,
    this.body,
    this.showCta = true,
  });

  final IconData icon;
  final String title;
  final String? body;
  final AppLocalizations l10n;
  final bool showCta;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: colors.textTertiary),
            const SizedBox(height: Space.x4),
            Text(
              title,
              style: context.type.display,
              textAlign: TextAlign.center,
            ),
            if (body != null) ...[
              const SizedBox(height: Space.x2),
              Text(
                body!,
                style: context.type.body.copyWith(color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            if (showCta) ...[
              const SizedBox(height: Space.x6),
              AppButton(
                label: l10n.ordersDiscoverCta,
                onPressed: () => const DiscoverRoute().go(context),
              ),
            ],
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
