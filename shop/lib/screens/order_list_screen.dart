import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/components/side_panel.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/domain/shop_order.dart';
import 'package:too_good_to_leave_shop/screens/order_detail_screen.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({required this.repository, super.key});

  final ShopRepository repository;

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  ShopOrderStatus? _statusFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openOrder(BuildContext context, ShopOrder order) {
    openDetail<void>(
      context,
      (_) => OrderDetailScreen(repository: widget.repository, order: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final now = widget.repository.clock.now();
        final allOrders = widget.repository.getOrders();

        // Repeat-customer counts are computed against every order, not the
        // filtered set — a customer's history doesn't change because a
        // filter happens to hide some of their other orders right now.
        final ordersByCustomer = <String, int>{};
        for (final o in allOrders) {
          ordersByCustomer[o.customerName] =
              (ordersByCustomer[o.customerName] ?? 0) + 1;
        }

        final query = _query.trim().toLowerCase();
        final orders = allOrders.where((o) {
          final matchesStatus =
              _statusFilter == null || o.status == _statusFilter;
          final matchesQuery =
              query.isEmpty ||
              o.customerName.toLowerCase().contains(query) ||
              o.bagTitle.toLowerCase().contains(query);
          return matchesStatus && matchesQuery;
        }).toList();

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

        final filtered = _statusFilter != null || query.isNotEmpty;

        return Scaffold(
          backgroundColor: colors.surfaceBase,
          appBar: AppBar(
            backgroundColor: colors.surfaceBase,
            title: Text('Orders', style: context.type.title),
          ),
          body: allOrders.isEmpty
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: 'Search by customer or bag',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                ),
                          isDense: true,
                          filled: true,
                          fillColor: colors.surfaceRaised,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(Radii.sm),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.x3),
                      Wrap(
                        spacing: Space.x2,
                        runSpacing: Space.x2,
                        children: [
                          _FilterChip(
                            label: 'All',
                            selected: _statusFilter == null,
                            onSelected: () =>
                                setState(() => _statusFilter = null),
                          ),
                          for (final status in ShopOrderStatus.values)
                            _FilterChip(
                              label: _statusLabel(status),
                              selected: _statusFilter == status,
                              onSelected: () =>
                                  setState(() => _statusFilter = status),
                            ),
                        ],
                      ),
                      const SizedBox(height: Space.x5),
                      if (orders.isEmpty)
                        Text(
                          'No orders match this filter.',
                          style: context.type.body.copyWith(
                            color: colors.textSecondary,
                          ),
                        )
                      else if (filtered)
                        _OrderWrap(
                          orders: orders,
                          ordersByCustomer: ordersByCustomer,
                          onTap: (o) => _openOrder(context, o),
                        )
                      else ...[
                        if (needsPrep.isNotEmpty) ...[
                          _SectionHeader('Needs prep now'),
                          _OrderWrap(
                            orders: needsPrep,
                            ordersByCustomer: ordersByCustomer,
                            onTap: (o) => _openOrder(context, o),
                          ),
                          const SizedBox(height: Space.x5),
                        ],
                        if (overdue.isNotEmpty) ...[
                          _SectionHeader('Overdue — no-show?'),
                          _OrderWrap(
                            orders: overdue,
                            ordersByCustomer: ordersByCustomer,
                            onTap: (o) => _openOrder(context, o),
                          ),
                          const SizedBox(height: Space.x5),
                        ],
                        if (rest.isNotEmpty) ...[
                          if (needsPrep.isNotEmpty || overdue.isNotEmpty)
                            _SectionHeader('All orders'),
                          _OrderWrap(
                            orders: rest,
                            ordersByCustomer: ordersByCustomer,
                            onTap: (o) => _openOrder(context, o),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }
}

String _statusLabel(ShopOrderStatus status) => switch (status) {
  ShopOrderStatus.reserved => 'Reserved',
  ShopOrderStatus.collected => 'Collected',
  ShopOrderStatus.expired => 'Expired',
  ShopOrderStatus.cancelled => 'Cancelled',
};

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: selected ? colors.actionPrimaryBg : colors.surfaceRaised,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.sm),
        onTap: onSelected,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.x3,
            vertical: Space.x2,
          ),
          child: Text(
            label,
            style: context.type.label.copyWith(
              color: selected ? colors.actionPrimaryFg : colors.textPrimary,
            ),
          ),
        ),
      ),
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
  const _OrderWrap({
    required this.orders,
    required this.ordersByCustomer,
    required this.onTap,
  });

  final List<ShopOrder> orders;
  final Map<String, int> ordersByCustomer;
  final ValueChanged<ShopOrder> onTap;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: Space.x3,
    runSpacing: Space.x3,
    children: [
      for (final order in orders)
        SizedBox(
          width: 380,
          child: _OrderCard(
            order: order,
            isRepeatCustomer: (ordersByCustomer[order.customerName] ?? 0) > 1,
            onTap: () => onTap(order),
          ),
        ),
    ],
  );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.isRepeatCustomer,
    required this.onTap,
  });

  final ShopOrder order;
  final bool isRepeatCustomer;
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'For ${order.customerName}',
                            overflow: TextOverflow.ellipsis,
                            style: context.type.body.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                        if (isRepeatCustomer) ...[
                          const SizedBox(width: Space.x2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Space.x2,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: colors.info.bg,
                              borderRadius: BorderRadius.circular(Radii.full),
                            ),
                            child: Text(
                              'Repeat',
                              style: context.type.caption.copyWith(
                                color: colors.info.fg,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
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
