import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/breakpoints.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/elevation.dart';
import 'package:too_good_to_leave_shop/screens/admin/admin_audit_log_screen.dart';
import 'package:too_good_to_leave_shop/screens/admin/admin_customers_screen.dart';
import 'package:too_good_to_leave_shop/screens/admin/admin_orders_screen.dart';
import 'package:too_good_to_leave_shop/screens/admin/admin_overview_screen.dart';
import 'package:too_good_to_leave_shop/screens/admin/admin_payouts_screen.dart';
import 'package:too_good_to_leave_shop/screens/admin/admin_pending_shops_screen.dart';
import 'package:too_good_to_leave_shop/screens/admin/admin_shops_screen.dart';

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
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    label: 'Overview',
  ),
  _Destination(
    icon: Icons.pending_actions_outlined,
    selectedIcon: Icons.pending_actions,
    label: 'Pending',
  ),
  _Destination(
    icon: Icons.storefront_outlined,
    selectedIcon: Icons.storefront,
    label: 'Shops',
  ),
  _Destination(
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
    label: 'Orders',
  ),
  _Destination(
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
    label: 'Customers',
  ),
  _Destination(
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet,
    label: 'Payouts',
  ),
  _Destination(
    icon: Icons.history_outlined,
    selectedIcon: Icons.history,
    label: 'Audit log',
  ),
];

/// The back office's own shell — same responsive-shell shape as
/// [ShopShellScreen] (persistent sidebar on desktop, floating pill nav on
/// mobile), kept as a separate widget rather than a variant of that one
/// since an admin session never has a [ShopRepository.profile] to show in
/// place of a business name, and needs a sign-out affordance that screen
/// doesn't.
class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({required this.repository, super.key});

  final ShopRepository repository;

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  int _index = 0;

  List<Widget> _pages() => [
    AdminOverviewScreen(repository: widget.repository),
    AdminPendingShopsScreen(repository: widget.repository),
    AdminShopsScreen(repository: widget.repository),
    AdminOrdersScreen(repository: widget.repository),
    AdminCustomersScreen(repository: widget.repository),
    AdminPayoutsScreen(repository: widget.repository),
    AdminAuditLogScreen(repository: widget.repository),
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
              onLogOut: widget.repository.logOut,
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
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        title: Text('Back office', style: context.type.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: widget.repository.logOut,
          ),
        ],
      ),
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

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogOut,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Future<void> Function() onLogOut;

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
                  const SizedBox(height: Space.x1),
                  Text('Back office', style: context.type.title),
                ],
              ),
            ),
            for (var i = 0; i < _destinations.length; i++)
              _SidebarItem(
                destination: _destinations[i],
                selected: i == selectedIndex,
                onTap: () => onSelect(i),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.x3,
                vertical: Space.x4,
              ),
              child: _SidebarItem(
                destination: const _Destination(
                  icon: Icons.logout,
                  selectedIcon: Icons.logout,
                  label: 'Log out',
                ),
                selected: false,
                onTap: onLogOut,
              ),
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
  final void Function() onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.x3, vertical: 2),
      child: Material(
        color: selected ? colors.actionPrimaryBg : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.sm),
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
