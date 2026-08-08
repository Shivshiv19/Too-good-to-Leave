import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/core/utils/formatters.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/components/app_button.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/domain/payout.dart';
import 'package:too_good_to_leave_shop/domain/shop_order.dart';

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({required this.repository, super.key});

  final ShopRepository repository;

  Future<void> _requestPayout(BuildContext context) async {
    final payout = await repository.requestPayout();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          payout == null
              ? 'Nothing to pay out right now.'
              : 'Payout of ${Fmt.money(payout.amount)} requested.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        final collectedOrders = repository
            .getOrders()
            .where((o) => o.status == ShopOrderStatus.collected)
            .toList();
        final payouts = repository.getPayouts();

        return Scaffold(
          backgroundColor: colors.surfaceBase,
          appBar: AppBar(
            backgroundColor: colors.surfaceBase,
            title: Text('Payments', style: context.type.title),
          ),
          body: ListView(
            padding: const EdgeInsets.all(Space.x4),
            children: [
              Container(
                padding: const EdgeInsets.all(Space.x4),
                decoration: BoxDecoration(
                  color: colors.actionPrimaryBg,
                  borderRadius: BorderRadius.circular(Radii.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available for payout',
                      style: context.type.label.copyWith(
                        color: colors.textOnAction.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: Space.x1),
                    Text(
                      Fmt.money(repository.pendingPayoutAmount),
                      style: context.type.display.copyWith(
                        color: colors.textOnAction,
                      ),
                    ),
                    const SizedBox(height: Space.x1),
                    Text(
                      'All-time earned: ${Fmt.money(repository.totalEarnedAllTime)}',
                      style: context.type.caption.copyWith(
                        color: colors.textOnAction.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: Space.x4),
                    AppButton(
                      label: 'Request payout',
                      variant: AppButtonVariant.secondary,
                      onPressed: () => _requestPayout(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.x6),
              Text('Order earnings', style: context.type.title),
              const SizedBox(height: Space.x3),
              if (collectedOrders.isEmpty)
                Text(
                  'No collected orders yet.',
                  style: context.type.body.copyWith(
                    color: colors.textSecondary,
                  ),
                )
              else
                ...collectedOrders.map(
                  (order) => Padding(
                    padding: const EdgeInsets.only(bottom: Space.x3),
                    child: _EarningsCard(order: order),
                  ),
                ),
              const SizedBox(height: Space.x6),
              Text('Payout history', style: context.type.title),
              const SizedBox(height: Space.x3),
              if (payouts.isEmpty)
                Text(
                  'No payouts requested yet.',
                  style: context.type.body.copyWith(
                    color: colors.textSecondary,
                  ),
                )
              else
                ...payouts.reversed.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: Space.x3),
                    child: _PayoutCard(payout: p),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({required this.order});

  final ShopOrder order;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final breakdown = EarningsBreakdown(gross: order.price);

    return Container(
      padding: const EdgeInsets.all(Space.x4),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(order.bagTitle, style: context.type.label),
          const SizedBox(height: Space.x2),
          _AmountRow(label: 'Gross', value: Fmt.money(breakdown.gross)),
          _AmountRow(
            label: 'Platform commission (${(commissionRate * 100).round()}%)',
            value: '−${Fmt.money(breakdown.commission)}',
            muted: true,
          ),
          const Divider(),
          _AmountRow(
            label: 'Net earned',
            value: Fmt.money(breakdown.net),
            emphasize: true,
          ),
        ],
      ),
    );
  }
}

class _PayoutCard extends StatelessWidget {
  const _PayoutCard({required this.payout});

  final PayoutRecord payout;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final date = payout.requestedAt;

    return Container(
      padding: const EdgeInsets.all(Space.x4),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style: context.type.body,
                ),
                Text(
                  '${payout.orderIds.length} order'
                  '${payout.orderIds.length == 1 ? '' : 's'}',
                  style: context.type.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            Fmt.money(payout.amount),
            style: context.type.label,
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.muted = false,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool muted;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = muted ? colors.textSecondary : colors.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: context.type.body.copyWith(color: color)),
          Text(
            value,
            style: emphasize
                ? context.type.label.copyWith(color: colors.textPrimary)
                : context.type.body.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
