import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:surplus_marketplace/features/auth/auth.dart';
import 'package:surplus_marketplace/features/orders/domain/entities/order_list_segment.dart';
import 'package:surplus_marketplace/features/orders/domain/repositories/orders_repository.dart';

part 'orders_providers.g.dart';

/// The DI seam (Phase 8 §8.6). Overridden in `bootstrap.dart`.
@riverpod
OrdersRepository ordersRepository(Ref ref) => throw UnimplementedError(
  'ordersRepositoryProvider has no override — set one in bootstrap.dart.',
);

/// §5d.1's Orders tab badge — "counts orders whose window is open or
/// opening within the hour". **Load-bearing, not decorative**: it's the
/// in-app substitute that carries the load when notification permission
/// was denied (§5c.9).
///
/// Not `keepAlive` — `AppShellScreen` re-invalidates this on a timer so the
/// badge stays roughly current without the full A14 5-second pickup-screen
/// cadence, which is specific to a user actively standing at a counter.
@riverpod
Future<int> ordersBadgeCount(Ref ref) async {
  final customer = await ref.read(authRepositoryProvider).restoreSession();
  if (customer == null) return 0;
  final orders = await ref
      .read(ordersRepositoryProvider)
      .getOrders(segment: OrderListSegment.active, customerId: customer.id);
  final now = DateTime.now();
  return orders
      .where(
        (o) =>
            o.pickupWindow.startAt.isBefore(now.add(const Duration(hours: 1))),
      )
      .length;
}
