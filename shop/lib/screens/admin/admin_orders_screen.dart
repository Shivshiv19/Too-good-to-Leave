import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/core/domain/money.dart';
import 'package:too_good_to_leave_shop/core/utils/formatters.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/components/app_button.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/domain/admin_models.dart';

/// The 200 most recent orders across every shop — see
/// [ShopRepository.adminGetOrders]'s own doc for why that's a plain limit
/// rather than real pagination/search: enough to spot and act on something
/// recent, not a full ops console.
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({required this.repository, super.key});

  final ShopRepository repository;

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  late Future<List<AdminOrderSummary>> _future = widget.repository
      .adminGetOrders();
  final _busyIds = <String>{};

  Future<void> _reload() async {
    setState(() => _future = widget.repository.adminGetOrders());
    await _future;
  }

  Future<void> _cancel(AdminOrderSummary order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel order ${order.orderCode}?'),
        content: const Text(
          "This marks the order cancelled and gives the stock back to the "
          "shop's listing. The customer's refund still needs to be handled "
          "through your payment provider directly — this app doesn't "
          'process payments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Back'),
          ),
          AppButton(
            label: 'Cancel order',
            variant: AppButtonVariant.destructive,
            expand: false,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    setState(() => _busyIds.add(order.id));
    try {
      await widget.repository.adminCancelOrder(order.id);
      await _reload();
    } finally {
      if (mounted) setState(() => _busyIds.remove(order.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        title: Text('Orders', style: context.type.title),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<AdminOrderSummary>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData && !snapshot.hasError) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: Space.x12),
                  Center(
                    child: Text(
                      "Couldn't load orders.",
                      style: context.type.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              );
            }
            final orders = snapshot.data!;
            if (orders.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: Space.x12),
                  Center(
                    child: Text(
                      'No orders yet.',
                      style: context.type.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(Space.x4),
              itemCount: orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: Space.x3),
              itemBuilder: (context, i) {
                final order = orders[i];
                return _OrderRow(
                  order: order,
                  busy: _busyIds.contains(order.id),
                  onCancel: () => _cancel(order),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

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

class _OrderRow extends StatelessWidget {
  const _OrderRow({
    required this.order,
    required this.busy,
    required this.onCancel,
  });

  final AdminOrderSummary order;
  final bool busy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(Space.x4),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(order.bagTitle, style: context.type.title),
              ),
              _StatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: Space.x1),
          Text(
            '${order.shopName} · for ${order.customerName}',
            style: context.type.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: Space.x1),
          Text(
            '${order.orderCode} · ${Fmt.money(Money(order.totalPaise))}',
            style: context.type.caption.copyWith(
              color: colors.textSecondary,
            ),
          ),
          if (order.isCancellable) ...[
            const SizedBox(height: Space.x3),
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                label: 'Cancel order',
                variant: AppButtonVariant.destructive,
                size: AppButtonSize.small,
                expand: false,
                isLoading: busy,
                onPressed: busy ? null : onCancel,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
