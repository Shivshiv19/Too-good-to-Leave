import 'dart:convert';
import 'dart:typed_data';

import 'package:too_good_to_leave_shop/core/domain/dietary_envelope.dart';
import 'package:too_good_to_leave_shop/core/domain/money.dart';
import 'package:too_good_to_leave_shop/core/domain/pickup_window.dart';

// `Money`/`PickupWindow` are copied verbatim from the customer app's
// `core/domain` (kept identical so the two apps' wire shapes never drift),
// so their (de)serialization lives here at the shop-specific call site
// rather than as app-specific additions to those shared files.
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

PickupWindow _pickupWindowFromJson(Map<String, dynamic> json) => PickupWindow(
  startAt: DateTime.parse(json['startAt'] as String),
  endAt: DateTime.parse(json['endAt'] as String),
);

/// Fixed vocabulary for [ShopBag.tags] — a small, shop-editable set of
/// meal-time/category labels (distinct from the shop's own single
/// [ShopCategory], which describes the business, not any one bag).
const bagTagOptions = [
  'Breakfast',
  'Lunch',
  'Dinner',
  'Dessert',
  'Snacks',
  'Beverages',
];

/// Whether a listing is visible to customers.
enum BagStatus {
  /// Being edited, not yet visible.
  draft,

  /// Visible and reservable.
  live,

  /// Visible but temporarily not reservable (e.g. sold out for today).
  paused,
}

/// A surprise bag as the shop sees and edits it.
///
/// Deliberately a different shape from the customer-facing `BagSummary`/
/// `SurpriseBag` (the read-only, fixed-content types the customer app
/// consumes) — this is the *editable* source a shop owner fills in, before
/// it becomes something a customer sees.
final class ShopBag {
  ShopBag({
    required this.id,
    required this.title,
    required this.description,
    required this.envelope,
    required this.price,
    required this.quantityAvailable,
    required this.pickupWindow,
    this.status = BagStatus.draft,
    this.photoBytes,
    this.repeatsDaily = false,
    this.tags = const [],
  });

  final String id;
  final String title;
  final String description;
  final DietaryEnvelope envelope;
  final Money price;
  final int quantityAvailable;
  final PickupWindow pickupWindow;
  final BagStatus status;

  /// Meal-time/category labels from [bagTagOptions] — lets a shop filter
  /// its own catalog once it has more than a handful of bags.
  final List<String> tags;

  /// `null` renders the design system's own placeholder convention — a
  /// striped block with a caption — rather than a broken-image icon.
  final Uint8List? photoBytes;

  /// Informational only in this standalone build — there's no backend
  /// scheduler to actually auto-republish a bag every day, so this is a
  /// badge the shop sets as a reminder to duplicate today's listing
  /// tomorrow, not an automation that fires on its own.
  final bool repeatsDaily;

  ShopBag copyWith({
    String? title,
    String? description,
    DietaryEnvelope? envelope,
    Money? price,
    int? quantityAvailable,
    PickupWindow? pickupWindow,
    BagStatus? status,
    Uint8List? photoBytes,
    bool? repeatsDaily,
    List<String>? tags,
  }) => ShopBag(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    envelope: envelope ?? this.envelope,
    price: price ?? this.price,
    quantityAvailable: quantityAvailable ?? this.quantityAvailable,
    pickupWindow: pickupWindow ?? this.pickupWindow,
    status: status ?? this.status,
    photoBytes: photoBytes ?? this.photoBytes,
    repeatsDaily: repeatsDaily ?? this.repeatsDaily,
    tags: tags ?? this.tags,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'envelope': envelope.wireValue,
    'price': _moneyToJson(price),
    'quantityAvailable': quantityAvailable,
    'pickupWindow': _pickupWindowToJson(pickupWindow),
    'status': status.name,
    'photoBytes': photoBytes == null ? null : base64Encode(photoBytes!),
    'repeatsDaily': repeatsDaily,
    'tags': tags,
  };

  factory ShopBag.fromJson(Map<String, dynamic> json) => ShopBag(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    envelope: DietaryEnvelope.fromWire(json['envelope'] as String),
    price: _moneyFromJson(json['price'] as Map<String, dynamic>),
    quantityAvailable: json['quantityAvailable'] as int,
    pickupWindow: _pickupWindowFromJson(
      json['pickupWindow'] as Map<String, dynamic>,
    ),
    status: BagStatus.values.byName(json['status'] as String),
    photoBytes: json['photoBytes'] == null
        ? null
        : base64Decode(json['photoBytes'] as String),
    repeatsDaily: json['repeatsDaily'] as bool? ?? false,
    tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
  );
}
