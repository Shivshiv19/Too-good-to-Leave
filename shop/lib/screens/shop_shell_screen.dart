import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/breakpoints.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/elevation.dart';
import 'package:too_good_to_leave_shop/screens/account_screen.dart';
import 'package:too_good_to_leave_shop/screens/analytics_screen.dart';
import 'package:too_good_to_leave_shop/screens/bag_list_screen.dart';
import 'package:too_good_to_leave_shop/screens/order_list_screen.dart';
import 'package:too_good_to_leave_shop/screens/payments_screen.dart';

class _Destination {
  const _Destination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

const _destinations = [
  _Destination(
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2,
    label: 'Bags',
  ),
  _Destination(
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
    label: 'Orders',
  ),
  _Destination(
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet,
    label: 'Payments',
  ),
  _Destination(
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights,
    label: 'Insights',
  ),
  _Destination(
    icon: Icons.storefront_outlined,
    selectedIcon: Icons.storefront,
    label: 'Account',
  ),
];

/// The shop app's shell — a SaaS-platform layout first: a persistent left
/// sidebar on desktop-width screens, collapsing to a floating pill bottom
/// nav (the original mobile-first design) below [Breakpoints.desktop].
/// `IndexedStack` + `setState`, no router, since this standalone tool
/// doesn't need deep-linking.
class ShopShellScreen extends StatefulWidget {
  const ShopShellScreen({required this.repository, super.key});

  final ShopRepository repository;

  @override
  State<ShopShellScreen> createState() => _ShopShellScreenState();
}

class _ShopShellScreenState extends State<ShopShellScreen> {
  int _index = 0;

  List<Widget> _pages() => [
    BagListScreen(repository: widget.repository),
    OrderListScreen(repository: widget.repository),
    PaymentsScreen(repository: widget.repository),
    AnalyticsScreen(repository: widget.repository),
    AccountScreen(repository: widget.repository),
  ];

  @override
  Widget build(BuildContext context) {
    if (context.isDesktopWidth) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(
              selectedIndex: _index,
              onSelect: (i) => setState(() => _index = i),
              businessName: widget.repository.profile?.businessName ?? '',
            ),
            Expanded(
              child: IndexedStack(index: _index, children: _pages()),
            ),
          ],
        ),
      );
    }

    final colors = context.colors;
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages()),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(Space.x4, 0, Space.x4, Space.x4),
        child: Material(
          color: colors.actionPrimaryBg,
          borderRadius: BorderRadius.circular(Radii.full),
          clipBehavior: Clip.antiAlias,
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
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                destinations: [
                  for (final d in _destinations)
                    NavigationDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: d.label,
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

/// The desktop-width nav — a fixed-width panel, persistent regardless of
/// which page is showing (unlike the mobile bottom nav, which is part of
/// each `Scaffold` frame). A SaaS dashboard convention: brand mark up top,
/// nav items below, always visible.
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selectedIndex,
    required this.onSelect,
    required this.businessName,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String businessName;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border(right: BorderSide(color: colors.borderSubtle)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.x5,
                Space.x6,
                Space.x5,
                Space.x6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Too Good To Leave', style: context.type.label),
                  if (businessName.isNotEmpty) ...[
                    const SizedBox(height: Space.x1),
                    Text(
                      businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.title,
                    ),
                  ],
                ],
              ),
            ),
            for (var i = 0; i < _destinations.length; i++)
              _SidebarItem(
                destination: _destinations[i],
                selected: i == selectedIndex,
                onTap: () => onSelect(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.x3, vertical: 2),
      child: Material(
        color: selected ? colors.actionPrimaryBg : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.full),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.full),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.x4,
              vertical: Space.x3,
            ),
            child: Row(
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 20,
                  color: selected
                      ? colors.actionPrimaryFg
                      : colors.textSecondary,
                ),
                const SizedBox(width: Space.x3),
                Text(
                  destination.label,
                  style: context.type.body.copyWith(
                    color: selected
                        ? colors.actionPrimaryFg
                        : colors.textPrimary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
