import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
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
        final orders = repository.getOrders();
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
              : ListView.separated(
                  padding: const EdgeInsets.all(Space.x4),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.x3),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _OrderCard(
                      order: order,
                      onTap: () => _openOrder(context, order),
                    );
                  },
                ),
        );
      },
    );
  }
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
