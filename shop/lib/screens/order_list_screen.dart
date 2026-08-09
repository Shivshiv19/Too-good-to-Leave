import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/components/max_width_body.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/domain/shop_order.dart';
import 'package:too_good_to_leave_shop/screens/order_detail_screen.dart';

class OrderListScreen extends StatelessWidget {
  const OrderListScreen({required this.repository, super.key});

  final ShopRepository repository;

  void _openOrder(BuildContext context, ShopOrder order) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(repository: repository, order: order),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        final now = repository.clock.now();
        final orders = repository.getOrders();

        // Currently collectable or starting soon — what the counter should
        // be getting ready right now.
        final needsPrep =
            orders
                .where(
                  (o) =>
                      o.status == ShopOrderStatus.reserved &&
                      !now.isAfter(o.pickupWindow.endAt) &&
                      o.pickupWindow.startAt.difference(now) <=
                          const Duration(hours: 2),
                )
                .toList()
              ..sort(
                (a, b) =>
                    a.pickupWindow.startAt.compareTo(b.pickupWindow.startAt),
              );

        // Reserved, but the window closed without a pickup confirmation —
        // candidates for marking a no-show.
        final overdue = orders
            .where(
              (o) =>
                  o.status == ShopOrderStatus.reserved &&
                  now.isAfter(o.pickupWindow.endAt),
            )
            .toList();

        final rest = orders
            .where((o) => !needsPrep.contains(o) && !overdue.contains(o))
            .toList();

        return Scaffold(
          backgroundColor: colors.surfaceBase,
          appBar: AppBar(
            backgroundColor: colors.surfaceBase,
            title: Text('Orders', style: context.type.title),
          ),
          body: orders.isEmpty
              ? Center(
                  child: Text(
                    'No orders yet.',
                    style: context.type.body.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(Space.x4),
                  child: MaxWidthBody(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (needsPrep.isNotEmpty) ...[
                          _SectionHeader('Needs prep now'),
                          _OrderWrap(
                            orders: needsPrep,
                            onTap: (o) => _openOrder(context, o),
                          ),
                          const SizedBox(height: Space.x5),
                        ],
                        if (overdue.isNotEmpty) ...[
                          _SectionHeader('Overdue — no-show?'),
                          _OrderWrap(
                            orders: overdue,
                            onTap: (o) => _openOrder(context, o),
                          ),
                          const SizedBox(height: Space.x5),
                        ],
                        if (rest.isNotEmpty) ...[
                          if (needsPrep.isNotEmpty || overdue.isNotEmpty)
                            _SectionHeader('All orders'),
                          _OrderWrap(
                            orders: rest,
                            onTap: (o) => _openOrder(context, o),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.x2),
    child: Text(
      text,
      style: context.type.label.copyWith(color: context.colors.textSecondary),
    ),
  );
}

class _OrderWrap extends StatelessWidget {
  const _OrderWrap({required this.orders, required this.onTap});

  final List<ShopOrder> orders;
  final ValueChanged<ShopOrder> onTap;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: Space.x3,
    runSpacing: Space.x3,
    children: [
      for (final order in orders)
        SizedBox(
          width: 380,
          child: _OrderCard(order: order, onTap: () => onTap(order)),
        ),
    ],
  );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final ShopOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.surfaceRaised,
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.x4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.bagTitle, style: context.type.title),
                    const SizedBox(height: Space.x1),
                    Text(
                      'For ${order.customerName}',
                      style: context.type.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: order.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ShopOrderStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (label, palette) = switch (status) {
      ShopOrderStatus.reserved => ('Reserved', colors.info),
      ShopOrderStatus.collected => ('Collected', colors.success),
      ShopOrderStatus.expired => ('Expired', colors.attention),
      ShopOrderStatus.cancelled => ('Cancelled', colors.critical),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.x2, vertical: 2),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(Radii.full),
      ),
      child: Text(
        label,
        style: context.type.caption.copyWith(
          color: palette.fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
