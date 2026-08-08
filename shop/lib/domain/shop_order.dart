import 'package:too_good_to_leave_shop/core/domain/pickup_token.dart';
import 'package:too_good_to_leave_shop/core/domain/pickup_window.dart';

/// Where an incoming reservation stands.
enum ShopOrderStatus {
  /// Reserved, awaiting collection.
  reserved,

  /// Collected — pickup confirmed.
  collected,

  /// Window closed without collection.
  expired,

  /// Customer or system cancelled before pickup.
  cancelled,
}

/// An incoming reservation, as the shop sees it.
///
/// Only carries what a counter needs to confirm a pickup — no payment or
/// customer-account detail crosses into the shop's view (a customer's name
/// is enough to greet them; nothing else is the shop's business).
final class ShopOrder {
  ShopOrder({
    required this.id,
    required this.bagTitle,
    required this.customerName,
    required this.pickupWindow,
    required this.token,
    this.status = ShopOrderStatus.reserved,
  });

  final String id;
  final String bagTitle;
  final String customerName;
  final PickupWindow pickupWindow;
  final PickupToken token;
  final ShopOrderStatus status;

  ShopOrder copyWith({ShopOrderStatus? status}) => ShopOrder(
    id: id,
    bagTitle: bagTitle,
    customerName: customerName,
    pickupWindow: pickupWindow,
    token: token,
    status: status ?? this.status,
  );
}
