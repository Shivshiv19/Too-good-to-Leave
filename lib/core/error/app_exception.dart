import 'package:surplus_marketplace/core/domain/money.dart';

/// Whether the customer's money actually moved.
///
/// **Amendment A13.** The natural copy for a failed payment is *"You haven't
/// been charged"* — but a client arriving at that screen after a UPI timeout
/// does **not** know it, and asserting it when a debit did occur is the most
/// damaging false statement this application could make.
///
/// So the server returns this definitively (Phase 7 §7.5) and the client
/// renders one of two authored variants. It never infers.
///
/// Defaulting to the reassuring variant when unsure is the tempting choice and
/// the wrong one: a user told they were not charged who then sees a debit
/// escalates to their bank and to a public review. A user told a refund may be
/// coming who then sees nothing debited has lost nothing.
enum ChargeState {
  /// Server-confirmed: no debit occurred.
  notCharged('not_charged'),

  /// Server-confirmed: a debit occurred.
  charged('charged'),

  /// Genuinely unknown. Must be surfaced honestly, not smoothed over.
  uncertain('uncertain');

  const ChargeState(this.wireValue);

  final String wireValue;

  static ChargeState fromWire(String? value) => ChargeState.values.firstWhere(
    (s) => s.wireValue == value,
    // The conservative fallback: if we cannot tell, say so.
    orElse: () => ChargeState.uncertain,
  );
}

/// Root of the application's error hierarchy (Phase 8 §8.5).
///
/// ## No user-facing strings live here
///
/// Errors carry a **stable code and typed details**. The `data` layer maps HTTP
/// status plus the Phase 7 §7.1.5 `code` onto these types; the `presentation`
/// layer maps a type onto an l10n key plus its data.
///
/// That two-stage split is what lets §C5 ("never surface a raw message") and the
/// i18n requirement be satisfied by one structure instead of fighting each
/// other. The typed details are what make §C5's *domain-specific* copy possible:
/// [BagSoldOut] carries the alternatives the screen has to offer, so the UI can
/// say "this bag just went — here are three others" instead of "error 409".
sealed class AppException implements Exception {
  const AppException({this.correlationId});

  /// Server request ID, surfaced only in an expandable "Details" affordance for
  /// support (§7.1.5) — never in primary copy.
  final String? correlationId;
}

// ---------------------------------------------------------------------------
// Transport and infrastructure
// ---------------------------------------------------------------------------

/// No usable connection.
final class NetworkException extends AppException {
  const NetworkException({super.correlationId});
}

/// The request exceeded its deadline.
final class RequestTimeoutException extends AppException {
  const RequestTimeoutException({super.correlationId});
}

/// 5xx. Retryable, with one silent backoff attempt before surfacing (§C5).
final class ServerException extends AppException {
  const ServerException({this.statusCode, super.correlationId});

  final int? statusCode;
}

/// The requested resource no longer exists — a delisted merchant, a bag ID
/// from a stale shared link, or an unknown/withdrawn category ID (§5b.7,
/// §5b.8, §5b.9). Rendered as a scoped not-found with a route back, never a
/// crash — the taxonomy and listings are server-driven and can change
/// between a link being shared and being opened.
final class NotFoundException extends AppException {
  const NotFoundException({super.correlationId});
}

// ---------------------------------------------------------------------------
// Session and lifecycle — these drive the §4.3 guard chain
// ---------------------------------------------------------------------------

/// Refresh failed, or a refresh token was replayed and its family revoked
/// (amendment A24). Routes to `/session-expired`, which leads with
/// *"Your orders are safe"* for exactly this reason (§5a.11).
final class SessionExpiredException extends AppException {
  const SessionExpiredException({super.correlationId});
}

/// This client version is no longer permitted to transact. Outranks every other
/// guard, including an in-flight payment (§4.3).
final class ForceUpdateException extends AppException {
  const ForceUpdateException({
    required this.storeUrl,
    this.reason,
    super.correlationId,
  });

  final String storeUrl;
  final String? reason;
}

/// Planned outage. [etaAt] is null when unknown — an unspecified outage reads as
/// abandonment, so the UI says so rather than implying a silent wait (§5a.10).
final class MaintenanceException extends AppException {
  const MaintenanceException({this.etaAt, super.correlationId});

  final DateTime? etaAt;
}

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------

/// Field-level rejection. Rendered inline at the offending field, never as a
/// banner (§C5).
final class ValidationException extends AppException {
  const ValidationException({required this.fieldErrors, super.correlationId});

  /// Field name → stable error code, mapped to copy in presentation.
  final Map<String, String> fieldErrors;
}

// ---------------------------------------------------------------------------
// Domain conflicts — every one of these needs authored, specific copy
// ---------------------------------------------------------------------------

/// A 409 with domain meaning.
///
/// §C5 forbids a generic conflict handler: each of these is a distinct product
/// situation with a distinct remedy, and collapsing them into "something went
/// wrong" throws away the only information the user needs.
sealed class DomainConflictException extends AppException {
  const DomainConflictException({super.correlationId});
}

/// The bag sold out. The §3.1/§3.2 race — frequent under burst supply, not an
/// edge case, which is why it carries alternatives rather than an apology.
final class BagSoldOutException extends DomainConflictException {
  const BagSoldOutException({
    this.alternativeBagIds = const [],
    super.correlationId,
  });

  final List<String> alternativeBagIds;
}

/// The merchant withdrew the listing.
final class BagWithdrawnException extends DomainConflictException {
  const BagWithdrawnException({
    this.alternativeBagIds = const [],
    super.correlationId,
  });

  final List<String> alternativeBagIds;
}

/// The pickup window closed before the reservation completed.
final class BagWindowClosedException extends DomainConflictException {
  const BagWindowClosedException({super.correlationId});
}

/// The cart hold lapsed.
///
/// Carries [bagId] so recovery is **one tap** — required by §C6 / WCAG 2.2.1:
/// nothing lost to a timer may be unrecoverable.
final class HoldExpiredException extends DomainConflictException {
  const HoldExpiredException({required this.bagId, super.correlationId});

  final String bagId;
}

/// Amendment A9 — the per-customer cap for this listing was reached.
final class PurchaseCapExceededException extends DomainConflictException {
  const PurchaseCapExceededException({
    required this.remainingAllowance,
    super.correlationId,
  });

  final int remainingAllowance;
}

/// A hold exists at a different merchant. Carts are single-merchant
/// (assumption A6), so this surfaces as an explicit replace-cart decision, never
/// a silent merge.
final class HoldConflictOtherMerchantException extends DomainConflictException {
  const HoldConflictOtherMerchantException({
    required this.existingMerchantName,
    super.correlationId,
  });

  final String existingMerchantName;
}

/// Amendment A15 — past the cancellation cutoff.
///
/// Eligibility is server-determined; the client renders [cutoffAt] and never
/// computes it.
final class CancellationWindowPassedException extends DomainConflictException {
  const CancellationWindowPassedException({
    required this.cutoffAt,
    super.correlationId,
  });

  final DateTime cutoffAt;
}

/// One review per collected order (§2.1).
final class ReviewAlreadyExistsException extends DomainConflictException {
  const ReviewAlreadyExistsException({
    required this.reviewId,
    super.correlationId,
  });

  final String reviewId;
}

/// A transactional notice cannot be dismissed while its order is live (§5e.1).
final class NotificationNotDismissibleException
    extends DomainConflictException {
  const NotificationNotDismissibleException({
    required this.orderId,
    super.correlationId,
  });

  final String orderId;
}

/// Amendment A20 — deletion blocked by a live order or an owed refund.
final class AccountDeletionBlockedException extends DomainConflictException {
  const AccountDeletionBlockedException({
    required this.blockers,
    super.correlationId,
  });

  /// Each blocker names its kind and the order it concerns, so the UI can offer
  /// a route to resolution rather than a flat refusal (§5f.11).
  final List<DeletionBlocker> blockers;
}

/// A reason account deletion is currently refused.
final class DeletionBlocker {
  const DeletionBlocker({required this.kind, required this.orderId});

  final DeletionBlockerKind kind;
  final String orderId;
}

/// Kinds of deletion blocker (§5f.11).
enum DeletionBlockerKind { activeOrder, pendingRefund }

// ---------------------------------------------------------------------------
// OTP
// ---------------------------------------------------------------------------

/// Wrong code. [attemptsRemaining] is shown explicitly — a silent rejection
/// leaves the user unable to judge whether to retry or start over (§5a.7).
final class OtpInvalidException extends AppException {
  const OtpInvalidException({
    required this.attemptsRemaining,
    super.correlationId,
  });

  final int attemptsRemaining;
}

/// The code aged out.
final class OtpExpiredException extends AppException {
  const OtpExpiredException({super.correlationId});
}

/// Too many wrong attempts; locked with a live countdown.
final class OtpAttemptsExhaustedException extends AppException {
  const OtpAttemptsExhaustedException({
    required this.retryAfter,
    super.correlationId,
  });

  final Duration retryAfter;
}

/// Too many code requests for this number.
final class OtpRateLimitedException extends AppException {
  const OtpRateLimitedException({
    required this.retryAfter,
    super.correlationId,
  });

  final Duration retryAfter;
}

/// The requested delivery channel is unavailable — the TRAI DLT reality
/// (Phase 1 §3.5). [channelsAvailable] drives the §5a.7 escalation ladder, so
/// the UI only ever offers a channel the server says will work.
final class OtpChannelUnavailableException extends AppException {
  const OtpChannelUnavailableException({
    required this.channelsAvailable,
    super.correlationId,
  });

  final List<String> channelsAvailable;
}

// ---------------------------------------------------------------------------
// Payment
// ---------------------------------------------------------------------------

/// A payment did not succeed.
///
/// [chargeState] is the whole point of this type (A13) and is **never inferred
/// client-side**. [amount] lets the failure screen state a refund figure
/// concretely when the state is uncertain.
final class PaymentFailedException extends AppException {
  const PaymentFailedException({
    required this.chargeState,
    required this.reason,
    this.amount,
    super.correlationId,
  });

  final ChargeState chargeState;

  /// Stable gateway reason code, mapped to authored copy in presentation.
  /// Raw gateway strings never reach the user (§C5).
  final String reason;

  final Money? amount;
}

/// Amendment A2 collision: the payment captured, but the bag went to someone
/// else while verification was in flight. Rare by design; still needs authored
/// copy and an automatic refund (§5c.6).
final class PaymentHoldCollisionException extends AppException {
  const PaymentHoldCollisionException({
    required this.orderId,
    required this.refundAmount,
    super.correlationId,
  });

  final String orderId;
  final Money refundAmount;
}
