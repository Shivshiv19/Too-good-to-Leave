import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/core/domain/money.dart';
import 'package:too_good_to_leave_shop/core/utils/day_bucket.dart';
import 'package:too_good_to_leave_shop/core/utils/formatters.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/domain/admin_models.dart';

enum _DateRangeMode {
  daily('Daily'),
  weekly('Weekly'),
  monthly('Monthly'),
  custom('Custom');

  const _DateRangeMode(this.label);
  final String label;
}

/// The back office's landing tab — platform-wide numbers across every shop
/// and every customer, in the same "date range + stat cards + trend
/// charts" shape as the shop app's own single-shop "Impact & analytics"
/// screen (see [ShopRepository.adminGetOverview]'s doc for how the two
/// share their underlying formulas).
class AdminOverviewScreen extends StatefulWidget {
  const AdminOverviewScreen({required this.repository, super.key});

  final ShopRepository repository;

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen> {
  _DateRangeMode _mode = _DateRangeMode.weekly;
  DateTimeRange? _customRange;
  late Future<AdminOverviewStats> _future = _load();

  DateTime get _today => dateOnly(widget.repository.clock.now());

  List<DateTime> get _days => switch (_mode) {
    _DateRangeMode.daily => lastNDays(_today, 1),
    _DateRangeMode.weekly => lastNDays(_today, 7),
    _DateRangeMode.monthly => lastNDays(_today, 30),
    _DateRangeMode.custom => _customRange == null
        ? lastNDays(_today, 7)
        : daysInRange(_customRange!.start, _customRange!.end),
  };

  Future<AdminOverviewStats> _load() =>
      widget.repository.adminGetOverview(_days);

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(_today.year - 2),
      lastDate: _today,
      initialDateRange:
          _customRange ??
          DateTimeRange(
            start: _today.subtract(const Duration(days: 6)),
            end: _today,
          ),
    );
    if (picked == null) return;
    setState(() {
      _customRange = picked;
      _mode = _DateRangeMode.custom;
    });
    await _reload();
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  String _periodLabel(List<DateTime> days) {
    if (days.length == 1) return 'on ${_fmtDate(days.first)}';
    return 'from ${_fmtDate(days.first)} to ${_fmtDate(days.last)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final days = _days;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        title: Text('Overview', style: context.type.title),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<AdminOverviewStats>(
          future: _future,
          builder: (context, snapshot) {
            final stats = snapshot.data;
            return ListView(
              padding: const EdgeInsets.all(Space.x4),
              children: [
                Wrap(
                  spacing: Space.x2,
                  runSpacing: Space.x2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final mode in _DateRangeMode.values)
                      _DateRangeChip(
                        label:
                            mode == _DateRangeMode.custom &&
                                _customRange != null
                            ? '${_fmtDate(_customRange!.start)} – '
                                  '${_fmtDate(_customRange!.end)}'
                            : mode.label,
                        selected: _mode == mode,
                        onSelected: () async {
                          if (mode == _DateRangeMode.custom) {
                            await _pickCustomRange();
                          } else {
                            setState(() => _mode = mode);
                            await _reload();
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: Space.x6),
                if (stats == null && !snapshot.hasError)
                  const Padding(
                    padding: EdgeInsets.only(top: Space.x12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.x12),
                    child: Center(
                      child: Text(
                        "Couldn't load the overview.",
                        style: context.type.body.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  )
                else ...[
                  Text('The business, right now', style: context.type.title),
                  const SizedBox(height: Space.x3),
                  Wrap(
                    spacing: Space.x3,
                    runSpacing: Space.x3,
                    children: [
                      SizedBox(
                        width: 220,
                        child: _StatCard(
                          icon: Icons.storefront,
                          label: 'Verified shops',
                          value: '${stats!.verifiedShopCount}',
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: _StatCard(
                          icon: Icons.pending_actions_outlined,
                          label: 'Pending shops',
                          value: '${stats.pendingShopCount}',
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: _StatCard(
                          icon: Icons.block_outlined,
                          label: 'Rejected shops',
                          value: '${stats.rejectedShopCount}',
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: _StatCard(
                          icon: Icons.people_outline,
                          label: 'Customers',
                          value: '${stats.customerCount}',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: Space.x8),
                  Text('Revenue', style: context.type.title),
                  const SizedBox(height: Space.x1),
                  Text(
                    'From ${stats.collectedInRange} collected order'
                    '${stats.collectedInRange == 1 ? '' : 's'} '
                    '${_periodLabel(days)}.',
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
                          icon: Icons.shopping_bag_outlined,
                          label: 'Gross revenue (GMV)',
                          value: Fmt.money(stats.grossRevenue),
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: _StatCard(
                          icon: Icons.savings_outlined,
                          label: 'Platform commission',
                          value: Fmt.money(stats.platformCommission),
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: _StatCard(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Paid out to shops',
                          value: Fmt.money(stats.shopPayouts),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: Space.x8),
                  Text('Orders', style: context.type.title),
                  const SizedBox(height: Space.x1),
                  Text(_periodLabel(days).replaceFirst('on', 'On').replaceFirst('from', 'From'),
                      style: context.type.caption.copyWith(color: colors.textSecondary)),
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
                          value: '${stats.ordersInRange}',
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: _StatCard(
                          icon: Icons.check_circle_outline,
                          label: 'Collected',
                          value: '${stats.collectedInRange}',
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: _StatCard(
                          icon: Icons.cancel_outlined,
                          label: 'Cancelled',
                          value: '${stats.cancelledInRange}',
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: _StatCard(
                          icon: Icons.event_busy,
                          label: 'No-show rate',
                          value: stats.concludedInRange == 0
                              ? '—'
                              : '${(stats.noShowRate * 100).round()}%',
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
                          subtitle:
                              'Gross revenue by order day, ${_periodLabel(days)}',
                          child: _RevenueTrendChart(
                            days: days,
                            revenueByDay: stats.revenueByDay,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 560,
                        child: _ChartCard(
                          title: 'Orders per day',
                          subtitle:
                              'Every order placed, ${_periodLabel(days)}',
                          child: _OrdersPerDayChart(
                            days: days,
                            ordersByDay: stats.ordersByDay,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: Space.x8),
                  Text('Top shops by revenue', style: context.type.title),
                  const SizedBox(height: Space.x3),
                  if (stats.topShopsByRevenue.isEmpty)
                    Text(
                      'No collected orders in this range yet.',
                      style: context.type.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    )
                  else
                    _TopShopsChart(shops: stats.topShopsByRevenue.take(6).toList()),

                  const SizedBox(height: Space.x8),
                  Text('Impact', style: context.type.title),
                  const SizedBox(height: Space.x1),
                  Text(
                    'Estimated from collected bags ${_periodLabel(days)} — '
                    'illustrative, not measured data.',
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
                          value: '${stats.mealsSaved}',
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: _StatCard(
                          icon: Icons.scale,
                          label: 'Food saved',
                          value: '${stats.kgSaved.toStringAsFixed(1)} kg',
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: _StatCard(
                          icon: Icons.eco,
                          label: 'CO₂e avoided',
                          value:
                              '${stats.co2eKgAvoided.toStringAsFixed(1)} kg',
                        ),
                      ),
                    ],
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

class _TopShopsChart extends StatelessWidget {
  const _TopShopsChart({required this.shops});

  final List<AdminShopRevenue> shops;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final maxPaise = shops.first.grossPaise;

    return Container(
      padding: const EdgeInsets.all(Space.x4),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final shop in shops)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.x3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(shop.shopName, style: context.type.body),
                      ),
                      Text(
                        Fmt.money(Money(shop.grossPaise)),
                        style: context.type.label,
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.x1),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.full),
                    child: LinearProgressIndicator(
                      value: maxPaise == 0 ? 0 : shop.grossPaise / maxPaise,
                      minHeight: 8,
                      backgroundColor: colors.surfaceSunken,
                      valueColor: AlwaysStoppedAnimation(
                        colors.actionPrimaryBg,
                      ),
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
