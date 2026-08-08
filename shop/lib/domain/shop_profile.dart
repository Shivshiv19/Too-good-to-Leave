import 'package:too_good_to_leave_shop/domain/shop_category.dart';

/// FSSAI licence — mandatory for any food business in India. The customer
/// app surfaces this on every merchant profile's legal-disclosure block;
/// this is where it's captured at source.
final class FssaiLicense {
  const FssaiLicense({required this.licenseNumber, required this.expiresAt});

  final String licenseNumber;
  final DateTime expiresAt;

  bool get isExpired => expiresAt.isBefore(DateTime.now());
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
    ShopApprovalStatus? status,
    String? rejectionReason,
  }) => ShopProfile(
    businessName: businessName,
    ownerName: ownerName,
    phone: phone,
    email: email,
    category: category,
    addressLine: addressLine,
    locality: locality,
    fssai: fssai,
    bankDetails: bankDetails,
    status: status ?? this.status,
    rejectionReason: rejectionReason ?? this.rejectionReason,
  );
}
