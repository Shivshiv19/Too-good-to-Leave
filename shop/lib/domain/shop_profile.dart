import 'package:too_good_to_leave_shop/domain/shop_category.dart';

/// FSSAI licence — mandatory for any food business in India. The customer
/// app surfaces this on every merchant profile's legal-disclosure block;
/// this is where it's captured at source.
final class FssaiLicense {
  const FssaiLicense({required this.licenseNumber, required this.expiresAt});

  final String licenseNumber;
  final DateTime expiresAt;

  bool get isExpired => expiresAt.isBefore(DateTime.now());

  Map<String, dynamic> toJson() => {
    'licenseNumber': licenseNumber,
    'expiresAt': expiresAt.toIso8601String(),
  };

  factory FssaiLicense.fromJson(Map<String, dynamic> json) => FssaiLicense(
    licenseNumber: json['licenseNumber'] as String,
    expiresAt: DateTime.parse(json['expiresAt'] as String),
  );
}

/// Payout destination. UPI is optional — a bank account is the minimum a
/// shop needs to receive money.
final class BankDetails {
  const BankDetails({
    required this.accountHolderName,
    required this.accountNumber,
    required this.ifscCode,
    this.upiId,
  });

  final String accountHolderName;
  final String accountNumber;
  final String ifscCode;
  final String? upiId;

  Map<String, dynamic> toJson() => {
    'accountHolderName': accountHolderName,
    'accountNumber': accountNumber,
    'ifscCode': ifscCode,
    'upiId': upiId,
  };

  factory BankDetails.fromJson(Map<String, dynamic> json) => BankDetails(
    accountHolderName: json['accountHolderName'] as String,
    accountNumber: json['accountNumber'] as String,
    ifscCode: json['ifscCode'] as String,
    upiId: json['upiId'] as String?,
  );
}

/// Where a registration stands.
enum ShopApprovalStatus {
  /// Submitted, awaiting review.
  pendingReview,

  /// Reviewed and cleared to list — the shop can use the rest of the app.
  verified,

  /// Reviewed and declined.
  rejected,
}

/// A registered shop's business profile.
final class ShopProfile {
  ShopProfile({
    required this.businessName,
    required this.ownerName,
    required this.phone,
    required this.email,
    required this.category,
    required this.addressLine,
    required this.locality,
    required this.fssai,
    required this.bankDetails,
    this.status = ShopApprovalStatus.pendingReview,
    this.rejectionReason,
  });

  final String businessName;
  final String ownerName;
  final String phone;
  final String email;
  final ShopCategory category;
  final String addressLine;
  final String locality;
  final FssaiLicense fssai;
  final BankDetails bankDetails;
  final ShopApprovalStatus status;

  /// Set only when [status] is [ShopApprovalStatus.rejected] — a shop that's
  /// been declined always knows why, never just "no."
  final String? rejectionReason;

  ShopProfile copyWith({
    String? businessName,
    String? ownerName,
    String? phone,
    String? email,
    ShopCategory? category,
    String? addressLine,
    String? locality,
    FssaiLicense? fssai,
    BankDetails? bankDetails,
    ShopApprovalStatus? status,
    String? rejectionReason,
  }) => ShopProfile(
    businessName: businessName ?? this.businessName,
    ownerName: ownerName ?? this.ownerName,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    category: category ?? this.category,
    addressLine: addressLine ?? this.addressLine,
    locality: locality ?? this.locality,
    fssai: fssai ?? this.fssai,
    bankDetails: bankDetails ?? this.bankDetails,
    status: status ?? this.status,
    rejectionReason: rejectionReason ?? this.rejectionReason,
  );

  Map<String, dynamic> toJson() => {
    'businessName': businessName,
    'ownerName': ownerName,
    'phone': phone,
    'email': email,
    'category': category.name,
    'addressLine': addressLine,
    'locality': locality,
    'fssai': fssai.toJson(),
    'bankDetails': bankDetails.toJson(),
    'status': status.name,
    'rejectionReason': rejectionReason,
  };

  factory ShopProfile.fromJson(Map<String, dynamic> json) => ShopProfile(
    businessName: json['businessName'] as String,
    ownerName: json['ownerName'] as String,
    phone: json['phone'] as String,
    email: json['email'] as String,
    category: ShopCategory.values.byName(json['category'] as String),
    addressLine: json['addressLine'] as String,
    locality: json['locality'] as String,
    fssai: FssaiLicense.fromJson(json['fssai'] as Map<String, dynamic>),
    bankDetails: BankDetails.fromJson(
      json['bankDetails'] as Map<String, dynamic>,
    ),
    status: ShopApprovalStatus.values.byName(json['status'] as String),
    rejectionReason: json['rejectionReason'] as String?,
  );
}
