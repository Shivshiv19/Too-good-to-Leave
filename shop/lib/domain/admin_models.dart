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
