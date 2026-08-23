import 'package:too_good_to_leave_shop/core/domain/money.dart';
import 'package:too_good_to_leave_shop/domain/shop_category.dart';
import 'package:too_good_to_leave_shop/domain/shop_profile.dart';

/// One shop as the back office sees it — every registered shop, regardless
/// of owner, unlike [ShopProfile] which is always "my own shop" from a
/// signed-in owner's point of view.
final class AdminShopSummary {
  const AdminShopSummary({
    required this.id,
    required this.businessName,
    required this.ownerName,
    required this.phone,
    required this.email,
    required this.category,
    required this.locality,
    required this.city,
    required this.status,
    required this.createdAt,
    this.rejectionReason,
  });

  final String id;
  final String businessName;
  final String ownerName;
  final String phone;
  final String email;
  final ShopCategory category;
  final String locality;
  final String city;
  final ShopApprovalStatus status;
  final DateTime createdAt;

  /// Set only when [status] is [ShopApprovalStatus.rejected] — same "always
  /// knows why" contract as [ShopProfile.rejectionReason].
  final String? rejectionReason;
}

/// Where an order stands — the database's own full vocabulary, not the
/// shop app's own narrower [ShopOrderStatus]. The back office needs the
/// finer detail (e.g. distinguishing a customer's own cancellation from a
/// merchant's) that the shop's simplified view deliberately collapses away.
enum AdminOrderStatus {
  pendingPayment,
  confirmed,
  paymentFailed,
  readyForPickup,
  collected,
  cancelledByCustomer,
  cancelledByMerchant,
  expiredUncollected,
}

/// One order as the back office sees it, across every shop and customer.
final class AdminOrderSummary {
  const AdminOrderSummary({
    required this.id,
    required this.orderCode,
    required this.shopName,
    required this.customerName,
    required this.bagTitle,
    required this.status,
    required this.createdAt,
    required this.totalPaise,
  });

  final String id;
  final String orderCode;
  final String shopName;
  final String customerName;
  final String bagTitle;
  final AdminOrderStatus status;
  final DateTime createdAt;
  final int totalPaise;

  /// Whether [ShopRepository.adminCancelOrder] can act on this order — a
  /// collected, expired, or already-cancelled order has nothing left to
  /// cancel.
  bool get isCancellable =>
      status == AdminOrderStatus.pendingPayment ||
      status == AdminOrderStatus.confirmed ||
      status == AdminOrderStatus.readyForPickup;
}

/// One shop's revenue within a reporting period — the back office's own
/// "best-selling bags" equivalent, ranked by shop instead of by bag.
final class AdminShopRevenue {
  const AdminShopRevenue({required this.shopName, required this.grossPaise});

  final String shopName;
  final int grossPaise;
}

/// The back office's platform-wide overview — every number sourced from
/// the same formulas the shop app's own single-shop "Impact & analytics"
/// screen already uses ([EarningsBreakdown]'s 20% commission split,
/// [ImpactEstimate]'s meals/kg/CO2e figures), just summed across every
/// shop and every customer instead of one shop's own data. Snapshot counts
/// (shops by status, total customers) aren't bounded by [days] — a shop
/// count is "right now," not "opened this week"; order-driven numbers
/// (revenue, order counts, the trend charts) are bounded by it.
final class AdminOverviewStats {
  const AdminOverviewStats({
    required this.verifiedShopCount,
    required this.pendingShopCount,
    required this.rejectedShopCount,
    required this.customerCount,
    required this.ordersInRange,
    required this.collectedInRange,
    required this.cancelledInRange,
    required this.noShowInRange,
    required this.grossRevenue,
    required this.platformCommission,
    required this.shopPayouts,
    required this.mealsSaved,
    required this.kgSaved,
    required this.co2eKgAvoided,
    required this.revenueByDay,
    required this.ordersByDay,
    required this.topShopsByRevenue,
  });

  final int verifiedShopCount;
  final int pendingShopCount;
  final int rejectedShopCount;
  final int customerCount;

  final int ordersInRange;
  final int collectedInRange;
  final int cancelledInRange;
  final int noShowInRange;

  final Money grossRevenue;
  final Money platformCommission;
  final Money shopPayouts;

  final int mealsSaved;
  final double kgSaved;
  final double co2eKgAvoided;

  /// Keyed by the same day-only [DateTime]s passed into
  /// [ShopRepository.adminGetOverview] — one entry per day in range, in
  /// paise, so the chart never has to guess at a missing day.
  final Map<DateTime, double> revenueByDay;
  final Map<DateTime, int> ordersByDay;

  /// Highest-grossing shops in range, already sorted descending — the
  /// caller just takes however many it wants to show.
  final List<AdminShopRevenue> topShopsByRevenue;

  /// Orders that reached a pickup-or-not outcome — the same "measured
  /// against concluded orders, not still-pending ones" reasoning the shop
  /// app's own no-show rate uses.
  int get concludedInRange => collectedInRange + cancelledInRange + noShowInRange;

  double get noShowRate =>
      concludedInRange == 0 ? 0 : noShowInRange / concludedInRange;
}
