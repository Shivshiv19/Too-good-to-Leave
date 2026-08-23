import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/core/domain/money.dart';
import 'package:too_good_to_leave_shop/core/utils/formatters.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/components/app_button.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/domain/admin_models.dart';
import 'package:too_good_to_leave_shop/screens/admin/refund_order_dialog.dart';

/// One order's full detail and timeline — reached by tapping a row on
/// [AdminOrdersScreen], the overview's "needs attention" list, or a
/// customer's own order history. The one place the back office can
/// actually issue a refund (see [AdminOrderDetail.isRefundable]).
class AdminOrderDetailScreen extends StatefulWidget {
  const AdminOrderDetailScreen({
    required this.repository,
    required this.orderId,
    super.key,
  });

  final ShopRepository repository;
  final String orderId;

  @override
  State<AdminOrderDetailScreen> createState() =>
      _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  late Future<AdminOrderDetail> _future = widget.repository.adminGetOrderDetail(
    widget.orderId,
  );
  bool _busy = false;

  Future<void> _reload() async {
    setState(
      () => _future = widget.repository.adminGetOrderDetail(widget.orderId),
    );
    await _future;
  }

  Future<void> _refund(AdminOrderDetail order) async {
    final reason = await showRefundOrderDialog(
      context,
      orderCode: order.orderCode,
    );
    if (reason == null) return;
    setState(() => _busy = true);
    try {
      await widget.repository.adminRefundOrder(order.id, reason: reason);
      await _reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        title: Text('Order detail', style: context.type.title),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<AdminOrderDetail>(
          future: _future,
          builder: (context, snapshot) {
            final order = snapshot.data;
            if (order == null && !snapshot.hasError) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: Space.x12),
                  Center(
                    child: Text(
                      "Couldn't load this order.",
                      style: context.type.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.all(Space.x4),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(order!.orderCode, style: context.type.headline),
                          const SizedBox(height: Space.x1),
                          Text(
                            order.bagTitle,
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
                const SizedBox(height: Space.x6),
                _DetailCard(
                  title: 'Who',
                  rows: [
                    ('Shop', order.shopName),
                    ('Customer', order.customerName),
                    ('Quantity', '${order.quantity}'),
                  ],
                ),
                const SizedBox(height: Space.x4),
                _DetailCard(
                  title: 'Money',
                  rows: [
                    ('Total', Fmt.money(Money(order.totalPaise))),
                    ('Payment status', _paymentStatusLabel(order.paymentStatus)),
                    if (order.refundedAt != null)
                      (
                        'Refunded',
                        '${Fmt.absoluteTime(order.refundedAt!, widget.repository.clock)}'
                            '${order.refundReason != null ? ' — ${order.refundReason}' : ''}',
                      ),
                  ],
                ),
                const SizedBox(height: Space.x4),
                _DetailCard(
                  title: 'Timeline',
                  rows: [
                    (
                      'Placed',
                      Fmt.absoluteTime(order.createdAt, widget.repository.clock),
                    ),
                    (
                      'Pickup window',
                      '${Fmt.timeOfDay(order.pickupStart)} – '
                          '${Fmt.timeOfDay(order.pickupEnd)}',
                    ),
                    if (order.collectedAt != null)
                      (
                        'Collected',
                        Fmt.absoluteTime(
                          order.collectedAt!,
                          widget.repository.clock,
                        ),
                      ),
                    if (order.cancelledAt != null)
                      (
                        'Cancelled',
                        '${Fmt.absoluteTime(order.cancelledAt!, widget.repository.clock)}'
                            '${order.cancellationReason != null ? ' — ${order.cancellationReason}' : ''}',
                      ),
                  ],
                ),
                if (order.isRefundable) ...[
                  const SizedBox(height: Space.x6),
                  AppButton(
                    label: 'Refund this order',
                    variant: AppButtonVariant.destructive,
                    isLoading: _busy,
                    onPressed: _busy ? null : () => _refund(order),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

String _paymentStatusLabel(String status) => switch (status) {
  'captured' => 'Paid',
  'refunded' => 'Refunded',
  'failed' => 'Failed',
  'refund_initiated' => 'Refund in progress',
  'refund_failed' => 'Refund failed',
  _ => status,
};

String _statusLabel(AdminOrderStatus status) => switch (status) {
  AdminOrderStatus.pendingPayment => 'Awaiting payment',
  AdminOrderStatus.confirmed => 'Reserved',
  AdminOrderStatus.paymentFailed => 'Payment failed',
  AdminOrderStatus.readyForPickup => 'Ready for pickup',
  AdminOrderStatus.collected => 'Collected',
  AdminOrderStatus.cancelledByCustomer => 'Cancelled by customer',
  AdminOrderStatus.cancelledByMerchant => 'Cancelled by shop',
  AdminOrderStatus.expiredUncollected => 'Expired, uncollected',
};

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final AdminOrderStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = switch (status) {
      AdminOrderStatus.collected => colors.success,
      AdminOrderStatus.paymentFailed ||
      AdminOrderStatus.cancelledByCustomer ||
      AdminOrderStatus.cancelledByMerchant ||
      AdminOrderStatus.expiredUncollected => colors.critical,
      AdminOrderStatus.pendingPayment => colors.attention,
      AdminOrderStatus.confirmed || AdminOrderStatus.readyForPickup =>
        colors.info,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.x2, vertical: 2),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(Radii.full),
      ),
      child: Text(
        _statusLabel(status),
        style: context.type.caption.copyWith(
          color: palette.fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.x4),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.type.label),
          const SizedBox(height: Space.x3),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.x2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      label,
                      style: context.type.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(value, style: context.type.body),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
