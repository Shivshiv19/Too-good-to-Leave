import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/core/domain/money.dart';
import 'package:too_good_to_leave_shop/core/utils/day_bucket.dart';
import 'package:too_good_to_leave_shop/core/utils/formatters.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/domain/impact_estimate.dart';
import 'package:too_good_to_leave_shop/domain/payout.dart';
import 'package:too_good_to_leave_shop/domain/shop_order.dart';

enum _DateRangeMode {
  daily('Daily'),
  weekly('Weekly'),
  monthly('Monthly'),
  custom('Custom');

  const _DateRangeMode(this.label);
  final String label;
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({required this.repository, super.key});

  final ShopRepository repository;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  _DateRangeMode _mode = _DateRangeMode.weekly;
  DateTimeRange? _customRange;

  Future<void> _pickCustomRange(DateTime today) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 2),
      lastDate: today,
      initialDateRange:
          _customRange ??
          DateTimeRange(start: today.subtract(const Duration(days: 6)), end: today),
    );
    if (picked == null) return;
    setState(() {
      _customRange = picked;
      _mode = _DateRangeMode.custom;
    });
  }

  List<DateTime> _selectedDays(DateTime today) => switch (_mode) {
    _DateRangeMode.daily => lastNDays(today, 1),
    _DateRangeMode.weekly => lastNDays(today, 7),
    _DateRangeMode.monthly => lastNDays(today, 30),
    _DateRangeMode.custom => _customRange == null
        ? lastNDays(today, 7)
        : daysInRange(_customRange!.start, _customRange!.end),
  };

  String _periodLabel(List<DateTime> days) {
    if (days.length == 1) return 'on ${_fmtDate(days.first)}';
    return 'from ${_fmtDate(days.first)} to ${_fmtDate(days.last)}';
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final repository = widget.repository;

    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        final today = dateOnly(repository.clock.now());
        final days = _selectedDays(today);
        final daySet = days.toSet();
        final orders = repository
            .getOrders()
            .where((o) => daySet.contains(dateOnly(o.pickupWindow.startAt)))
            .toList();
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

        final revenueByDay = <DateTime, double>{
          for (final d in days) d: 0,
        };
        for (final order in collected) {
          final d = dateOnly(order.pickupWindow.startAt);
          if (revenueByDay.containsKey(d)) {
            revenueByDay[d] =
                revenueByDay[d]! +
                EarningsBreakdown(gross: order.price).net.amountInPaise / 100;
          }
        }

        final ordersByDay = <DateTime, int>{
          for (final d in days) d: 0,
        };
        for (final order in orders) {
          final d = dateOnly(order.pickupWindow.startAt);
          if (ordersByDay.containsKey(d)) {
            ordersByDay[d] = ordersByDay[d]! + 1;
          }
        }

        return Scaffold(
          backgroundColor: colors.surfaceBase,
          appBar: AppBar(
            backgroundColor: colors.surfaceBase,
            title: Text('Impact & analytics', style: context.type.title),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: Space.x2,
                  runSpacing: Space.x2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final mode in _DateRangeMode.values)
                      _DateRangeChip(
                        label: mode == _DateRangeMode.custom &&
                                _customRange != null
                            ? '${_fmtDate(_customRange!.start)} – '
                                  '${_fmtDate(_customRange!.end)}'
                            : mode.label,
                        selected: _mode == mode,
                        onSelected: () => mode == _DateRangeMode.custom
                            ? _pickCustomRange(today)
                            : setState(() => _mode = mode),
                      ),
                  ],
                ),
                const SizedBox(height: Space.x6),
                Text('Your impact', style: context.type.title),
                const SizedBox(height: Space.x1),
                Text(
                  'Estimated from ${collected.length} collected bag'
                  '${collected.length == 1 ? '' : 's'} ${_periodLabel(days)} '
                  '— see the info note below for how these are calculated.',
                  style: context.type.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: Space.x3),
                Wrap(
                  spacing: Space.x3,
                  runSpacing: Space.x3,
                  children: [
                    SizedBox(
                      width: 220,
                      child: _StatCard(
                        icon: Icons.restaurant,
                        label: 'Meals saved',
                        value: '${ImpactEstimate.mealsSaved(collected.length)}',
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: _StatCard(
                        icon: Icons.scale,
                        label: 'Food saved',
                        value:
                            '${ImpactEstimate.kgSaved(collected.length).toStringAsFixed(1)} kg',
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: _StatCard(
                        icon: Icons.eco,
                        label: 'Estimated CO₂e avoided',
                        value:
                            '${ImpactEstimate.co2eKgAvoided(collected.length).toStringAsFixed(1)} kg',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.x2),
                Text(
                  'Meals saved = one per collected bag. Food saved '
                  'assumes ~${ImpactEstimate.kgPerBag} kg per bag; CO₂e '
                  'assumes ~${ImpactEstimate.co2eKgPerKgFood} kg CO₂e '
                  'avoided per kg of food. Both are illustrative '
                  'estimates, not measured data.',
                  style: context.type.caption.copyWith(
                    color: colors.textTertiary,
                  ),
                ),

                const SizedBox(height: Space.x8),
                Text('Orders', style: context.type.title),
                const SizedBox(height: Space.x3),
                Wrap(
                  spacing: Space.x3,
                  runSpacing: Space.x3,
                  children: [
                    SizedBox(
                      width: 220,
                      child: _StatCard(
                        icon: Icons.receipt_long,
                        label: 'Total orders',
                        value: '${orders.length}',
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: _StatCard(
                        icon: Icons.payments_outlined,
                        label: 'Net revenue',
                        value: Fmt.money(revenue),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: _StatCard(
                        icon: Icons.event_busy,
                        label: 'No-show rate',
                        value: concluded == 0
                            ? '—'
                            : '${(noShowRate * 100).round()}%',
                      ),
                    ),
                    SizedBox(
                      width: 220,
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
                Wrap(
                  spacing: Space.x3,
                  runSpacing: Space.x3,
                  children: [
                    SizedBox(
                      width: 560,
                      child: _ChartCard(
                        title: 'Revenue trend',
                        subtitle: 'Net revenue by pickup day, ${_periodLabel(days)}',
                        child: _RevenueTrendChart(
                          days: days,
                          revenueByDay: revenueByDay,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 560,
                      child: _ChartCard(
                        title: 'Orders per day',
                        subtitle: 'All orders by pickup day, ${_periodLabel(days)}',
                        child: _OrdersPerDayChart(
                          days: days,
                          ordersByDay: ordersByDay,
                        ),
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
                  _BestSellersChart(ranked: ranked),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DateRangeChip extends StatelessWidget {
  const _DateRangeChip({
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

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
          Icon(icon, color: colors.actionPrimaryBg),
          const SizedBox(height: Space.x2),
          Text(value, style: context.type.headline),
          Text(
            label,
            style: context.type.caption.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Shared card chrome for a chart — title, subtitle, then the chart itself
/// at a fixed height (fl_chart's widgets need a bounded height to lay out).
class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(Space.x4),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.type.title),
          const SizedBox(height: Space.x1),
          Text(
            subtitle,
            style: context.type.caption.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: Space.x4),
          SizedBox(height: 180, child: child),
        ],
      ),
    );
  }
}

class _RevenueTrendChart extends StatelessWidget {
  const _RevenueTrendChart({required this.days, required this.revenueByDay});

  final List<DateTime> days;
  final Map<DateTime, double> revenueByDay;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final maxY = revenueByDay.values.fold<double>(
      0,
      (max, v) => v > max ? v : max,
    );

    return LineChart(
      LineChartData(
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
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => colors.surfaceOverlay,
            getTooltipItems: (spots) => spots
                .map(
                  (s) => LineTooltipItem(
                    '₹${s.y.toStringAsFixed(0)}',
                    context.type.caption.copyWith(color: colors.textPrimary),
                  ),
                )
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < days.length; i++)
                FlSpot(i.toDouble(), revenueByDay[days[i]] ?? 0),
            ],
            isCurved: true,
            color: colors.actionPrimaryBg,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: colors.actionPrimaryBg.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersPerDayChart extends StatelessWidget {
  const _OrdersPerDayChart({required this.days, required this.ordersByDay});

  final List<DateTime> days;
  final Map<DateTime, int> ordersByDay;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final maxY = ordersByDay.values.fold<int>(0, (max, v) => v > max ? v : max);

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY <= 0 ? 1 : maxY.toDouble() + 1,
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
                  '${rod.toY.round()} order${rod.toY.round() == 1 ? '' : 's'}',
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
                  toY: (ordersByDay[days[i]] ?? 0).toDouble(),
                  color: colors.actionPrimaryBg,
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

class _BestSellersChart extends StatelessWidget {
  const _BestSellersChart({required this.ranked});

  final List<MapEntry<String, int>> ranked;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final top = ranked.take(6).toList();
    final maxCount = top.first.value;

    return Container(
      padding: const EdgeInsets.all(Space.x4),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in top)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.x3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                  const SizedBox(height: Space.x1),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.full),
                    child: LinearProgressIndicator(
                      value: entry.value / maxCount,
                      minHeight: 8,
                      backgroundColor: colors.surfaceSunken,
                      valueColor: AlwaysStoppedAnimation(colors.actionPrimaryBg),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
