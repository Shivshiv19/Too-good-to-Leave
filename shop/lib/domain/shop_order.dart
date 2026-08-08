import 'package:too_good_to_leave_shop/core/domain/money.dart';
import 'package:too_good_to_leave_shop/core/domain/pickup_token.dart';
import 'package:too_good_to_leave_shop/core/domain/pickup_window.dart';

Map<String, dynamic> _moneyToJson(Money money) => {
  'amountInPaise': money.amountInPaise,
  'currencyCode': money.currency.code,
};

Money _moneyFromJson(Map<String, dynamic> json) => Money(
  json['amountInPaise'] as int,
  currency: Currency.fromCode(json['currencyCode'] as String),
);

Map<String, dynamic> _pickupWindowToJson(PickupWindow window) => {
  'startAt': window.startAt.toIso8601String(),
  'endAt': window.endAt.toIso8601String(),
};

PickupWindow _pickupWindowFromJson(Map<String, dynamic> json) =>
    PickupWindow(
      startAt: DateTime.parse(json['startAt'] as String),
      endAt: DateTime.parse(json['endAt'] as String),
    );

Map<String, dynamic> _tokenToJson(PickupToken token) => {
  'rotatingPayload': token.rotatingPayload,
  'rotationExpiresAt': token.rotationExpiresAt.toIso8601String(),
  'offlineToken': token.offlineToken,
  'offlineTokenValidUntil': token.offlineTokenValidUntil.toIso8601String(),
  'fallbackCode': token.fallbackCode,
};

PickupToken _tokenFromJson(Map<String, dynamic> json) => PickupToken(
  rotatingPayload: json['rotatingPayload'] as String,
  rotationExpiresAt: DateTime.parse(json['rotationExpiresAt'] as String),
  offlineToken: json['offlineToken'] as String,
  offlineTokenValidUntil: DateTime.parse(
    json['offlineTokenValidUntil'] as String,
  ),
  fallbackCode: json['fallbackCode'] as String,
);

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
/// Carries what a counter needs to confirm a pickup, plus [price] — a
/// snapshot of what the bag cost at the moment it was reserved, the same
/// way the real customer-app `Order` entity snapshots price rather than
/// pointing back at a bag whose price could change later. No *payment
/// method* or customer-account detail crosses into the shop's view; the
/// price itself is legitimately needed here now for the payments/earnings
/// area (§8.12-shop area 5) — a shop has to know what it earned per order.
final class ShopOrder {
  ShopOrder({
    required this.id,
    required this.bagTitle,
    required this.customerName,
    required this.pickupWindow,
    required this.token,
    required this.price,
    this.status = ShopOrderStatus.reserved,
  });

  final String id;
  final String bagTitle;
  final String customerName;
  final PickupWindow pickupWindow;
  final PickupToken token;
  final Money price;
  final ShopOrderStatus status;

  ShopOrder copyWith({ShopOrderStatus? status}) => ShopOrder(
    id: id,
    bagTitle: bagTitle,
    customerName: customerName,
    pickupWindow: pickupWindow,
    token: token,
    price: price,
    status: status ?? this.status,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'bagTitle': bagTitle,
    'customerName': customerName,
    'pickupWindow': _pickupWindowToJson(pickupWindow),
    'token': _tokenToJson(token),
    'price': _moneyToJson(price),
    'status': status.name,
  };

  factory ShopOrder.fromJson(Map<String, dynamic> json) => ShopOrder(
    id: json['id'] as String,
    bagTitle: json['bagTitle'] as String,
    customerName: json['customerName'] as String,
    pickupWindow: _pickupWindowFromJson(
      json['pickupWindow'] as Map<String, dynamic>,
    ),
    token: _tokenFromJson(json['token'] as Map<String, dynamic>),
    price: _moneyFromJson(json['price'] as Map<String, dynamic>),
    status: ShopOrderStatus.values.byName(json['status'] as String),
  );
}
