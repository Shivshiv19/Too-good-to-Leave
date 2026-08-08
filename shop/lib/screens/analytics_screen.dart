import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/core/domain/money.dart';
import 'package:too_good_to_leave_shop/core/utils/formatters.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/domain/impact_estimate.dart';
import 'package:too_good_to_leave_shop/domain/payout.dart';
import 'package:too_good_to_leave_shop/domain/shop_order.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({required this.repository, super.key});

  final ShopRepository repository;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        final orders = repository.getOrders();
        final bags = repository.getBags();

        final collected = orders
            .where((o) => o.status == ShopOrderStatus.collected)
            .toList();
        final noShow = orders
            .where((o) => o.status == ShopOrderStatus.expired)
            .length;
        final cancelled = orders
            .where((o) => o.status == ShopOrderStatus.cancelled)
            .length;
        // No-show rate is measured against orders that actually reached a
        // pickup-or-not outcome — a still-reserved order hasn't happened
        // yet, so including it would understate the rate.
        final concluded = collected.length + noShow + cancelled;
        final noShowRate = concluded == 0 ? 0.0 : noShow / concluded;

        final ordersPerBag = <String, int>{};
        for (final order in orders) {
          ordersPerBag[order.bagTitle] =
              (ordersPerBag[order.bagTitle] ?? 0) + 1;
        }
        final ranked = ordersPerBag.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        var revenue = const Money.zero();
        for (final order in collected) {
          revenue += EarningsBreakdown(gross: order.price).net;
        }

        return Scaffold(
          backgroundColor: colors.surfaceBase,
          appBar: AppBar(
            backgroundColor: colors.surfaceBase,
            title: Text('Impact & analytics', style: context.type.title),
          ),
          body: ListView(
            padding: const EdgeInsets.all(Space.x4),
            children: [
              Text('Your impact', style: context.type.title),
              const SizedBox(height: Space.x1),
              Text(
                'Estimated from ${collected.length} collected bag'
                '${collected.length == 1 ? '' : 's'} — see the info note '
                'below for how these are calculated.',
                style: context.type.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: Space.x3),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.restaurant,
                      label: 'Meals saved',
                      value: '${ImpactEstimate.mealsSaved(collected.length)}',
                    ),
                  ),
                  const SizedBox(width: Space.x3),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.scale,
                      label: 'Food saved',
                      value:
                          '${ImpactEstimate.kgSaved(collected.length).toStringAsFixed(1)} kg',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.x3),
              _StatCard(
                icon: Icons.eco,
                label: 'Estimated CO₂e avoided',
                value:
                    '${ImpactEstimate.co2eKgAvoided(collected.length).toStringAsFixed(1)} kg',
                wide: true,
              ),
              const SizedBox(height: Space.x2),
              Text(
                'Meals saved = one per collected bag. Food saved assumes '
                '~${ImpactEstimate.kgPerBag} kg per bag; CO₂e assumes '
                '~${ImpactEstimate.co2eKgPerKgFood} kg CO₂e avoided per kg '
                'of food. Both are illustrative estimates, not measured '
                'data.',
                style: context.type.caption.copyWith(
                  color: colors.textTertiary,
                ),
              ),

              const SizedBox(height: Space.x8),
              Text('Orders', style: context.type.title),
              const SizedBox(height: Space.x3),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.receipt_long,
                      label: 'Total orders',
                      value: '${orders.length}',
                    ),
                  ),
                  const SizedBox(width: Space.x3),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.payments_outlined,
                      label: 'Net revenue',
                      value: Fmt.money(revenue),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.x3),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.event_busy,
                      label: 'No-show rate',
                      value: concluded == 0
                          ? '—'
                          : '${(noShowRate * 100).round()}%',
                    ),
                  ),
                  const SizedBox(width: Space.x3),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.inventory_2_outlined,
                      label: 'Live bags',
                      value:
                          '${bags.where((b) => b.status.name == 'live').length}',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: Space.x8),
              Text('Best-selling bags', style: context.type.title),
              const SizedBox(height: Space.x3),
              if (ranked.isEmpty)
                Text(
                  'No orders yet.',
                  style: context.type.body.copyWith(
                    color: colors.textSecondary,
                  ),
                )
              else
                ...ranked.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: Space.x2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(entry.key, style: context.type.body),
                        ),
                        Text(
                          '${entry.value} order${entry.value == 1 ? '' : 's'}',
                          style: context.type.label,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.wide = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.all(Space.x4),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.actionPrimaryBg),
          const SizedBox(height: Space.x2),
          Text(
            value,
            style: context.type.headline,
          ),
          Text(
            label,
            style: context.type.caption.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
