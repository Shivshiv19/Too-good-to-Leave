import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/design_system/foundations/elevation.dart';
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
      // A floating pill nav rather than a full-width bar — the "Too Good To
      // Leave" rebrand's signature shape, matching the pill treatment given
      // to every other tappable horizontal control (buttons, chips).
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          Space.x4,
          0,
          Space.x4,
          Space.x4 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Material(
          color: colors.actionPrimaryBg,
          borderRadius: BorderRadius.circular(Radii.full),
          clipBehavior: Clip.antiAlias,
          shadowColor: Colors.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: Elevation.overlay.shadowsFor(colors.brightness),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                navigationBarTheme: NavigationBarThemeData(
                  backgroundColor: Colors.transparent,
                  indicatorColor: colors.textOnAction.withValues(alpha: 0.16),
                  height: 64,
                  labelTextStyle: WidgetStateProperty.resolveWith(
                    (states) => context.type.caption.copyWith(
                      color: colors.textOnAction,
                      fontWeight: states.contains(WidgetState.selected)
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  iconTheme: WidgetStateProperty.resolveWith(
                    (states) => IconThemeData(color: colors.textOnAction),
                  ),
                ),
              ),
              child: NavigationBar(
                backgroundColor: Colors.transparent,
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
      ),
    );
  }
}
