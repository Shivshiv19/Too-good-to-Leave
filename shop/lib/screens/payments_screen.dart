import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/core/utils/csv_download.dart';
import 'package:too_good_to_leave_shop/core/utils/day_bucket.dart';
import 'package:too_good_to_leave_shop/core/utils/formatters.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/components/app_button.dart';
import 'package:too_good_to_leave_shop/design_system/components/side_panel.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/breakpoints.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/domain/payout.dart';
import 'package:too_good_to_leave_shop/domain/shop_order.dart';
import 'package:too_good_to_leave_shop/screens/order_detail_screen.dart';

/// Trend chart look-back window, matching the Insights tab.
const _trendDays = 14;

/// Payout policy: weekly, every Monday, covering everything collected the
/// week before. There's no real payment processor behind this (see
/// `requestPayout`'s own doc) — this is a schedule label, not a promise
/// money moves on that date.
DateTime _nextPayoutDate(DateTime today) {
  final diff = (DateTime.monday - today.weekday + 7) % 7;
  return today.add(Duration(days: diff == 0 ? 7 : diff));
}

String _csvEscape(String field) {
  if (field.contains(',') || field.contains('"') || field.contains('\n')) {
    return '"${field.replaceAll('"', '""')}"';
  }
  return field;
}

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

  void _downloadStatement(List<ShopOrder> collectedOrders) {
    final buffer = StringBuffer()
      ..writeln(
        'Date,Bag,Customer,Gross,Commission,GST on commission,Net earned',
      );
    for (final order in collectedOrders) {
      final breakdown = EarningsBreakdown(gross: order.price);
      final d = order.pickupWindow.startAt;
      buffer.writeln(
        [
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
          order.bagTitle,
          order.customerName,
          breakdown.gross.wholeUnits,
          breakdown.commission.wholeUnits,
          breakdown.gstOnCommission.wholeUnits,
          breakdown.net.wholeUnits,
        ].map((v) => _csvEscape('$v')).join(','),
      );
    }
    downloadCsv(
      'earnings_statement_${DateTime.now().millisecondsSinceEpoch}.csv',
      buffer.toString(),
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
        final today = dateOnly(repository.clock.now());
        final nextPayout = _nextPayoutDate(today);
        final days = lastNDays(today, _trendDays);

        final commissionByDay = <DateTime, double>{
          for (final d in days) d: 0,
        };
        for (final order in collectedOrders) {
          final d = dateOnly(order.pickupWindow.startAt);
          if (commissionByDay.containsKey(d)) {
            commissionByDay[d] =
                commissionByDay[d]! +
                EarningsBreakdown(
                      gross: order.price,
                    ).commission.amountInPaise /
                    100;
          }
        }

        return Scaffold(
          backgroundColor: colors.surfaceBase,
          appBar: AppBar(
            backgroundColor: colors.surfaceBase,
            title: Text('Payments', style: context.type.title),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PayoutHeroCards(
                  repository: repository,
                  nextPayout: nextPayout,
                  onRequestPayout: () => _requestPayout(context),
                ),

                const SizedBox(height: Space.x6),
                Row(
                  children: [
                    Expanded(
                      child: Text('Order earnings', style: context.type.title),
                    ),
                    if (collectedOrders.isNotEmpty)
                      AppButton(
                        label: 'Download statement (CSV)',
                        variant: AppButtonVariant.tertiary,
                        icon: Icons.download_outlined,
                        expand: false,
                        onPressed: () => _downloadStatement(collectedOrders),
                      ),
                  ],
                ),
                const SizedBox(height: Space.x3),
                if (collectedOrders.isEmpty)
                  Text(
                    'No collected orders yet.',
                    style: context.type.body.copyWith(
                      color: colors.textSecondary,
                    ),
                  )
                else ...[
                  Wrap(
                    spacing: Space.x3,
                    runSpacing: Space.x3,
                    children: [
                      for (final order in collectedOrders)
                        SizedBox(
                          width: 340,
                          child: _EarningsCard(
                            order: order,
                            onTap: () => openDetail<void>(
                              context,
                              (_) => _EarningsDetailPanel(
                                repository: repository,
                                order: order,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.x6),
                  Container(
                    padding: const EdgeInsets.all(Space.x4),
                    decoration: BoxDecoration(
                      color: colors.surfaceRaised,
                      borderRadius: BorderRadius.circular(Radii.card),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Commission trend', style: context.type.title),
                        const SizedBox(height: Space.x1),
                        Text(
                          'Platform commission by pickup day, last $_trendDays days',
                          style: context.type.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: Space.x4),
                        SizedBox(
                          height: 180,
                          child: _CommissionTrendChart(
                            days: days,
                            commissionByDay: commissionByDay,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

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
                  Wrap(
                    spacing: Space.x3,
                    runSpacing: Space.x3,
                    children: [
                      for (final p in payouts.reversed)
                        SizedBox(
                          width: 340,
                          child: _PayoutCard(
                            payout: p,
                            onTap: () => openDetail<void>(
                              context,
                              (_) => _PayoutDetailPanel(
                                repository: repository,
                                payout: p,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The two hero cards atop Payments — side by side with matched heights on
/// desktop widths (an [IntrinsicHeight] `Row`, since [Wrap] doesn't equalise
/// heights across a run), stacked full-width below the breakpoint where
/// there's no room for two 340px-minimum cards side by side.
class _PayoutHeroCards extends StatelessWidget {
  const _PayoutHeroCards({
    required this.repository,
    required this.nextPayout,
    required this.onRequestPayout,
  });

  final ShopRepository repository;
  final DateTime nextPayout;
  final VoidCallback onRequestPayout;

  @override
  Widget build(BuildContext context) {
    final available = _AvailableForPayoutCard(
      repository: repository,
      onRequestPayout: onRequestPayout,
    );
    final next = _NextScheduledPayoutCard(nextPayout: nextPayout);

    if (!context.isDesktopWidth) {
      return Column(
        children: [available, const SizedBox(height: Space.x3), next],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: available),
          const SizedBox(width: Space.x3),
          Expanded(child: next),
        ],
      ),
    );
  }
}

class _AvailableForPayoutCard extends StatelessWidget {
  const _AvailableForPayoutCard({
    required this.repository,
    required this.onRequestPayout,
  });

  final ShopRepository repository;
  final VoidCallback onRequestPayout;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.x4),
      decoration: BoxDecoration(
        color: colors.actionPrimaryBg,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
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
            ],
          ),
          const SizedBox(height: Space.x4),
          SizedBox(
            width: 220,
            child: _WhiteOutlinedButton(
              label: 'Request payout',
              onPressed: onRequestPayout,
            ),
          ),
        ],
      ),
    );
  }
}

class _NextScheduledPayoutCard extends StatelessWidget {
  const _NextScheduledPayoutCard({required this.nextPayout});

  final DateTime nextPayout;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.x4),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_repeat, color: colors.actionPrimaryBg),
              const SizedBox(width: Space.x2),
              Text('Next scheduled payout', style: context.type.label),
            ],
          ),
          const SizedBox(height: Space.x2),
          Text(
            '${nextPayout.day}/${nextPayout.month}/${nextPayout.year}',
            style: context.type.headline,
          ),
          const SizedBox(height: Space.x1),
          Text(
            'Payouts run weekly, every Monday, for orders collected the '
            'week before. This is a demo schedule — no money actually '
            'moves in this build.',
            style: context.type.caption.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// A pill button with a white border and white label — the shop's regular
/// [AppButtonVariant.secondary] renders in the brand green, which vanishes
/// against this card's brand-green fill. This is the "on a coloured
/// surface" counterpart AppButton itself doesn't have a variant for.
class _WhiteOutlinedButton extends StatelessWidget {
  const _WhiteOutlinedButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: Colors.white, width: 1.5),
      borderRadius: BorderRadius.circular(Radii.full),
    ),
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(Radii.full),
      child: Container(
        constraints: const BoxConstraints(minHeight: Layout.minTouchTarget),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x5,
          vertical: Space.x3,
        ),
        child: Text(
          label,
          style: context.type.label.copyWith(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

class _CommissionTrendChart extends StatelessWidget {
  const _CommissionTrendChart({
    required this.days,
    required this.commissionByDay,
  });

  final List<DateTime> days;
  final Map<DateTime, double> commissionByDay;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final maxY = commissionByDay.values.fold<double>(
      0,
      (max, v) => v > max ? v : max,
    );

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY <= 0 ? 1 : maxY * 1.2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (days.length / 4).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= days.length) return const SizedBox.shrink();
                final d = days[i];
                return Padding(
                  padding: const EdgeInsets.only(top: Space.x1),
                  child: Text(
                    '${d.day}/${d.month}',
                    style: context.type.caption.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => colors.surfaceOverlay,
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                BarTooltipItem(
                  '₹${rod.toY.toStringAsFixed(0)}',
                  context.type.caption.copyWith(color: colors.textPrimary),
                ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: commissionByDay[days[i]] ?? 0,
                  color: colors.attention.fg,
                  width: 12,
                  borderRadius: BorderRadius.circular(Radii.sm / 3),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({required this.order, required this.onTap});

  final ShopOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final breakdown = EarningsBreakdown(gross: order.price);

    return Material(
      color: colors.surfaceRaised,
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(order.bagTitle, style: context.type.label),
              const SizedBox(height: Space.x2),
              _AmountRow(label: 'Gross', value: Fmt.money(breakdown.gross)),
              _AmountRow(
                label:
                    'Platform commission (${(commissionRate * 100).round()}%)',
                value: '−${Fmt.money(breakdown.commission)}',
                muted: true,
              ),
              _AmountRow(
                label:
                    '  incl. GST on commission (${(gstOnCommissionRate * 100).round()}%)',
                value: Fmt.money(breakdown.gstOnCommission),
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
        ),
      ),
    );
  }
}

class _PayoutCard extends StatelessWidget {
  const _PayoutCard({required this.payout, required this.onTap});

  final PayoutRecord payout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final date = payout.requestedAt;

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
              Text(Fmt.money(payout.amount), style: context.type.label),
            ],
          ),
        ),
      ),
    );
  }
}

/// Side-panel detail view for a single collected order's earnings — the
/// same breakdown [_EarningsCard] shows inline, with room for a link back
/// to the order itself.
class _EarningsDetailPanel extends StatelessWidget {
  const _EarningsDetailPanel({required this.repository, required this.order});

  final ShopRepository repository;
  final ShopOrder order;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final breakdown = EarningsBreakdown(gross: order.price);

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        title: Text(order.bagTitle, style: context.type.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'For ${order.customerName}',
              style: context.type.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: Space.x1),
            Text(
              Fmt.pickupWindow(order.pickupWindow, repository.clock),
              style: context.type.caption.copyWith(
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(height: Space.x6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Space.x4),
              decoration: BoxDecoration(
                color: colors.surfaceRaised,
                borderRadius: BorderRadius.circular(Radii.card),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AmountRow(label: 'Gross', value: Fmt.money(breakdown.gross)),
                  _AmountRow(
                    label:
                        'Platform commission (${(commissionRate * 100).round()}%)',
                    value: '−${Fmt.money(breakdown.commission)}',
                    muted: true,
                  ),
                  _AmountRow(
                    label:
                        '  incl. GST on commission (${(gstOnCommissionRate * 100).round()}%)',
                    value: Fmt.money(breakdown.gstOnCommission),
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
            ),
            const SizedBox(height: Space.x6),
            AppButton(
              label: 'View order',
              variant: AppButtonVariant.secondary,
              onPressed: () => openDetail<void>(
                context,
                (_) => OrderDetailScreen(repository: repository, order: order),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Side-panel detail view for a payout — the collected orders it covers,
/// each with its own gross/commission/net.
class _PayoutDetailPanel extends StatelessWidget {
  const _PayoutDetailPanel({required this.repository, required this.payout});

  final ShopRepository repository;
  final PayoutRecord payout;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final date = payout.requestedAt;
    final ordersById = {for (final o in repository.getOrders()) o.id: o};

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        title: Text(
          '${date.day}/${date.month}/${date.year} payout',
          style: context.type.title,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Space.x4),
              decoration: BoxDecoration(
                color: colors.actionPrimaryBg,
                borderRadius: BorderRadius.circular(Radii.card),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paid out',
                    style: context.type.label.copyWith(
                      color: colors.textOnAction.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: Space.x1),
                  Text(
                    Fmt.money(payout.amount),
                    style: context.type.display.copyWith(
                      color: colors.textOnAction,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.x6),
            Text(
              'Orders included (${payout.orderIds.length})',
              style: context.type.title,
            ),
            const SizedBox(height: Space.x3),
            for (final id in payout.orderIds)
              if (ordersById[id] case final order?)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.x2),
                  child: Material(
                    color: colors.surfaceRaised,
                    borderRadius: BorderRadius.circular(Radii.card),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Radii.card),
                      onTap: () => openDetail<void>(
                        context,
                        (_) => OrderDetailScreen(
                          repository: repository,
                          order: order,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(Space.x4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order.bagTitle,
                                    style: context.type.body,
                                  ),
                                  Text(
                                    'For ${order.customerName}',
                                    style: context.type.caption.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              Fmt.money(
                                EarningsBreakdown(gross: order.price).net,
                              ),
                              style: context.type.label,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        ),
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
