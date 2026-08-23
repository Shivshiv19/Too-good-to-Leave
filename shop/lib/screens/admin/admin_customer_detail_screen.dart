import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/core/domain/money.dart';
import 'package:too_good_to_leave_shop/core/utils/formatters.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/domain/admin_models.dart';
import 'package:too_good_to_leave_shop/screens/admin/admin_order_detail_screen.dart';

/// One customer's own order history — reached by tapping a row on
/// [AdminCustomersScreen]. Surfaces exactly what a support conversation
/// needs: every order this customer has placed, and how each one went.
class AdminCustomerDetailScreen extends StatefulWidget {
  const AdminCustomerDetailScreen({
    required this.repository,
    required this.customer,
    super.key,
  });

  final ShopRepository repository;
  final AdminCustomerSummary customer;

  @override
  State<AdminCustomerDetailScreen> createState() =>
      _AdminCustomerDetailScreenState();
}

class _AdminCustomerDetailScreenState
    extends State<AdminCustomerDetailScreen> {
  late Future<List<AdminOrderSummary>> _future = widget.repository
      .adminGetOrdersForCustomer(widget.customer.id);

  Future<void> _reload() async {
    setState(
      () => _future = widget.repository.adminGetOrdersForCustomer(
        widget.customer.id,
      ),
    );
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final customer = widget.customer;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        title: Text(customer.name, style: context.type.title),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(Space.x4),
          children: [
            Container(
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
                  Text(
                    Fmt.maskedPhone(customer.phoneE164),
                    style: context.type.body,
                  ),
                  if (customer.email != null && customer.email!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.x1),
                      child: Text(customer.email!, style: context.type.body),
                    ),
                  const SizedBox(height: Space.x1),
                  Text(
                    'Joined ${Fmt.absoluteTime(customer.createdAt, widget.repository.clock)}',
                    style: context.type.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.x6),
            Text('Orders', style: context.type.title),
            const SizedBox(height: Space.x3),
            FutureBuilder<List<AdminOrderSummary>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData && !snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.only(top: Space.x8),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Text(
                    "Couldn't load this customer's orders.",
                    style: context.type.body.copyWith(
                      color: colors.textSecondary,
                    ),
                  );
                }
                final orders = snapshot.data!;
                if (orders.isEmpty) {
                  return Text(
                    'No orders from this customer yet.',
                    style: context.type.body.copyWith(
                      color: colors.textSecondary,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final order in orders) ...[
                      _CustomerOrderRow(
                        order: order,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => AdminOrderDetailScreen(
                                repository: widget.repository,
                                orderId: order.id,
                              ),
                            ),
                          );
                          await _reload();
                        },
                      ),
                      const SizedBox(height: Space.x3),
                    ],
                  ],
                );
              },
            ),
          ],
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

class _CustomerOrderRow extends StatelessWidget {
  const _CustomerOrderRow({required this.order, required this.onTap});

  final AdminOrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = switch (order.status) {
      AdminOrderStatus.collected => colors.success,
      AdminOrderStatus.paymentFailed ||
      AdminOrderStatus.cancelledByCustomer ||
      AdminOrderStatus.cancelledByMerchant ||
      AdminOrderStatus.expiredUncollected => colors.critical,
      AdminOrderStatus.pendingPayment => colors.attention,
      AdminOrderStatus.confirmed || AdminOrderStatus.readyForPickup =>
        colors.info,
    };
    return Material(
      color: colors.surfaceRaised,
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(Space.x4),
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
                    Text(order.bagTitle, style: context.type.body),
                    const SizedBox(height: Space.x1),
                    Text(
                      '${order.orderCode} · ${order.shopName} · '
                      '${Fmt.money(Money(order.totalPaise))}',
                      style: context.type.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.x2,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: palette.bg,
                  borderRadius: BorderRadius.circular(Radii.full),
                ),
                child: Text(
                  _statusLabel(order.status),
                  style: context.type.caption.copyWith(
                    color: palette.fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
