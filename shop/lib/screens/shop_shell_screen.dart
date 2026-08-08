import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/elevation.dart';
import 'package:too_good_to_leave_shop/screens/account_screen.dart';
import 'package:too_good_to_leave_shop/screens/bag_list_screen.dart';
import 'package:too_good_to_leave_shop/screens/order_list_screen.dart';

/// The shop app's tab shell. A floating pill nav, matching the customer
/// app's rebrand (`app_shell_screen.dart` there), kept intentionally simple
/// here (`IndexedStack` + `setState`, no router) since this standalone tool
/// doesn't need deep-linking.
class ShopShellScreen extends StatefulWidget {
  const ShopShellScreen({required this.repository, super.key});

  final ShopRepository repository;

  @override
  State<ShopShellScreen> createState() => _ShopShellScreenState();
}

class _ShopShellScreenState extends State<ShopShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          BagListScreen(repository: widget.repository),
          OrderListScreen(repository: widget.repository),
          AccountScreen(repository: widget.repository),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.x4,
          0,
          Space.x4,
          Space.x4,
        ),
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
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.inventory_2_outlined),
                    selectedIcon: Icon(Icons.inventory_2),
                    label: 'Bags',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long),
                    label: 'Orders',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.storefront_outlined),
                    selectedIcon: Icon(Icons.storefront),
                    label: 'Account',
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
