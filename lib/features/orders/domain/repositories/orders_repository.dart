import 'dart:typed_data';

import 'package:surplus_marketplace/core/domain/pickup_token.dart';
import 'package:surplus_marketplace/features/checkout/checkout.dart';
import 'package:surplus_marketplace/features/orders/domain/entities/cancellation_eligibility.dart';
import 'package:surplus_marketplace/features/orders/domain/entities/issue_report.dart';
import 'package:surplus_marketplace/features/orders/domain/entities/issue_type.dart';
import 'package:surplus_marketplace/features/orders/domain/entities/order_list_segment.dart';
import 'package:surplus_marketplace/features/orders/domain/entities/refund_detail.dart';

/// Phase 7 §7.6 — Orders and pickup (Phase 8 §8.12 step 7).
///
/// **No dependency on `catalog`** (§8.3.2) — every read here works off the
/// immutable snapshot already embedded in [Order], never a live catalog
/// lookup.
abstract interface class OrdersRepository {
  /// Throws nothing — an empty list is a normal, expected result (§5d.1's
  /// empty states are not errors). `customerId` is explicit, matching
  /// `CheckoutRepository.createOrder`'s own convention (Phase 8 §8.12 step
  /// 6) rather than a repository reaching into auth state internally.
  Future<List<Order>> getOrders({
    required OrderListSegment segment,
    required String customerId,
  });

  /// Throws `NotFoundException` — deleted, or belongs to another account
  /// (§5d.2).
  Future<Order> getOrder(String orderId);

  /// **A1** — the three-layer credential. Throws `NotFoundException`.
  Future<PickupToken> getPickupToken(String orderId);

  /// **A15** — server-determined; the client renders this, never computes
  /// it. Throws `NotFoundException`.
  Future<CancellationEligibility> getCancellationEligibility(String orderId);

  /// Throws `CancellationWindowPassedException` past the cutoff,
  /// `NotFoundException` for an unknown order.
  Future<Order> cancelOrder(String orderId, {String? reason});

  /// Throws `NotFoundException`.
  Future<RefundDetail> getRefund(String orderId);

  /// Presigned-upload stand-in — returns an opaque attachment id. Never
  /// throws on a slow network in the fake; a real implementation's failure
  /// is exactly what §5d.6 requires callers to tolerate (submit without the
  /// photo, offer retry).
  Future<String> uploadAttachment(Uint8List bytes, {required String filename});

  /// **A16** — `type.isFoodSafety` routes to the escalation class with its
  /// own SLA, encoded in the returned [IssueReport.slaHours].
  Future<IssueReport> reportIssue({
    required String orderId,
    required IssueType type,
    required String description,
    List<String> attachmentIds = const [],
  });
}
