import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/features/orders/orders.dart';

/// The four-tab bottom navigation shell (Phase 4 §4.1, §2.4).
///
/// `StatefulShellRoute.indexedStack` — one persistent `Navigator` per tab, so
/// switching Discover → Orders → Discover preserves each branch's scroll and
/// filter state, rather than sharing a single back stack (§4.1's rejection
/// of a plain `go_router` single stack).
class AppShellScreen extends ConsumerStatefulWidget {
  const AppShellScreen({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends ConsumerState<AppShellScreen> {
  Timer? _badgeRefreshTimer;

  @override
  void initState() {
    super.initState();
    // §5d.1's Orders badge is load-bearing, not decorative, but this app
    // has no push-driven cache invalidation yet — a minute-scale timer is
    // the interim substitute, distinct from the Pickup screen's own A14
    // 5-second cadence (which is specific to a user standing at a counter).
    _badgeRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => ref.invalidate(ordersBadgeCountProvider),
    );
  }

  @override
  void dispose() {
    _badgeRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final badgeCount = ref.watch(ordersBadgeCountProvider).value ?? 0;

    return Scaffold(
      body: widget.navigationShell,
      // Flat, full-width, light-cream bar — a soft mint pill highlights
      // whichever tab is active, rather than the whole bar being filled
      // green (the prior floating-pill treatment). A hairline top border
      // stands in for elevation, the same "stroke instead of shadow" idea
      // used everywhere else in this theme.
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          border: Border(top: BorderSide(color: colors.borderSubtle)),
        ),
        child: SafeArea(
          child: Theme(
            data: Theme.of(context).copyWith(
              navigationBarTheme: NavigationBarThemeData(
                backgroundColor: Colors.transparent,
                indicatorColor: colors.actionPrimaryBg.withValues(alpha: 0.14),
                indicatorShape: const StadiumBorder(),
                height: 64,
                labelTextStyle: WidgetStateProperty.resolveWith(
                  (states) => context.type.caption.copyWith(
                    color: states.contains(WidgetState.selected)
                        ? colors.actionPrimaryBg
                        : colors.textSecondary,
                    fontWeight: states.contains(WidgetState.selected)
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                iconTheme: WidgetStateProperty.resolveWith(
                  (states) => IconThemeData(
                    color: states.contains(WidgetState.selected)
                        ? colors.actionPrimaryBg
                        : colors.textSecondary,
                  ),
                ),
              ),
            ),
            child: NavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedIndex: widget.navigationShell.currentIndex,
              onDestinationSelected: (index) =>
                  widget.navigationShell.goBranch(
                    index,
                    // Tapping the already-active tab pops it back to its
                    // root, matching the platform convention for a tab
                    // that preserves per-branch navigation state (§4.1).
                    initialLocation:
                        index == widget.navigationShell.currentIndex,
                  ),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.storefront_outlined),
                  selectedIcon: const Icon(Icons.storefront),
                  label: l10n.navDiscover,
                ),
                NavigationDestination(
                  icon: badgeCount > 0
                      ? Badge(
                          label: Text('$badgeCount'),
                          child: const Icon(Icons.receipt_long_outlined),
                        )
                      : const Icon(Icons.receipt_long_outlined),
                  selectedIcon: const Icon(Icons.receipt_long),
                  label: l10n.navOrders,
                  tooltip: badgeCount > 0
                      ? l10n.navOrdersBadgeSemantic(badgeCount)
                      : l10n.navOrders,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.bookmark_border),
                  selectedIcon: const Icon(Icons.bookmark),
                  label: l10n.navSaved,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person_outline),
                  selectedIcon: const Icon(Icons.person),
                  label: l10n.navAccount,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
