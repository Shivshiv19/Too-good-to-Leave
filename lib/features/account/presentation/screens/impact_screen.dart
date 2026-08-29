import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/domain/impact_estimate.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/auth/auth.dart';
import 'package:surplus_marketplace/features/checkout/checkout.dart';
import 'package:surplus_marketplace/features/orders/orders.dart';

enum _Phase { loading, loaded, error }

/// §4.2 `/account/impact` — a customer-facing mirror of the shop app's own
/// "Insights" impact cards (`shop/lib/screens/analytics_screen.dart`), same
/// `ImpactEstimate` formula, computed here from this customer's own
/// collected orders instead of one shop's collected bags.
class ImpactScreen extends ConsumerStatefulWidget {
  const ImpactScreen({super.key});

  @override
  ConsumerState<ImpactScreen> createState() => _ImpactScreenState();
}

class _ImpactScreenState extends ConsumerState<ImpactScreen> {
  _Phase _phase = _Phase.loading;
  int _collectedCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final customer = await ref.read(authRepositoryProvider).restoreSession();
      if (customer == null) {
        // The Account screen only links here when signed in (§5f.1's gated
        // menu pattern); defensive only.
        if (mounted) setState(() => _phase = _Phase.error);
        return;
      }
      final orders = await ref
          .read(ordersRepositoryProvider)
          .getOrders(segment: OrderListSegment.past, customerId: customer.id);
      final collected = orders
          .where((o) => o.status == OrderStatus.collected)
          .length;
      if (!mounted) return;
      setState(() {
        _collectedCount = collected;
        _phase = _Phase.loaded;
      });
    } on Object {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        elevation: 0,
        title: Text(l10n.impactTitle, style: context.type.title),
      ),
      body: SafeArea(child: _buildBody(context, l10n)),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    final colors = context.colors;
    switch (_phase) {
      case _Phase.loading:
        return const Center(child: CircularProgressIndicator());
      case _Phase.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.x6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.errorServerTitle, style: context.type.title),
                const SizedBox(height: Space.x2),
                Text(
                  l10n.errorServerBody,
                  style: context.type.body.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      case _Phase.loaded:
        if (_collectedCount == 0) return _EmptyState(l10n: l10n);
        return ListView(
          padding: const EdgeInsets.all(Space.x4),
          children: [
            Text(
              l10n.impactSubtitle(_collectedCount),
              style: context.type.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: Space.x4),
            _ImpactCard(
              icon: Icons.restaurant,
              label: l10n.impactMealsSaved,
              value: '${ImpactEstimate.mealsSaved(_collectedCount)}',
            ),
            const SizedBox(height: Space.x3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ImpactCard(
                    icon: Icons.scale,
                    label: l10n.impactFoodSaved,
                    value:
                        '${ImpactEstimate.kgSaved(_collectedCount).toStringAsFixed(1)} kg',
                    stacked: true,
                  ),
                ),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: _ImpactCard(
                    icon: Icons.eco,
                    label: l10n.impactCo2Avoided,
                    value:
                        '${ImpactEstimate.co2eKgAvoided(_collectedCount).toStringAsFixed(1)} kg',
                    stacked: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.x4),
            Text(
              l10n.impactMethodologyNote(
                ImpactEstimate.kgPerBag.toString(),
                ImpactEstimate.co2eKgPerKgFood.toString(),
              ),
              style: context.type.caption.copyWith(
                color: colors.textTertiary,
              ),
            ),
          ],
        );
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco_outlined, size: 64, color: colors.textTertiary),
            const SizedBox(height: Space.x4),
            Text(
              l10n.impactEmptyTitle,
              style: context.type.display,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.x2),
            Text(
              l10n.impactEmptyBody,
              style: context.type.body.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ImpactCard extends StatelessWidget {
  const _ImpactCard({
    required this.icon,
    required this.label,
    required this.value,
    this.stacked = false,
  });

  final IconData icon;
  final String label;
  final String value;

  /// A narrower, icon-above-value layout for the two-up grid (food saved /
  /// CO2e avoided) — [Row] would clip at half the screen's width.
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final content = stacked
        ? [
            Icon(icon, color: colors.actionPrimaryBg, size: 24),
            const SizedBox(height: Space.x2),
            Text(
              value,
              style: context.type.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: context.type.labelSmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ]
        : [
            Icon(icon, color: colors.actionPrimaryBg, size: 28),
            const SizedBox(width: Space.x4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: context.type.headline),
                  Text(
                    label,
                    style: context.type.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.x4),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: stacked
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: content)
          : Row(children: content),
    );
  }
}
