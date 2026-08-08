import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/core/utils/formatters.dart';

/// User-facing copy for one error, resolved from an [AppException].
///
/// [body] is optional because some errors are a headline only. [recoveryHint]
/// names the action the caller should offer, so screens don't each invent their
/// own recovery vocabulary.
final class ErrorCopy {
  const ErrorCopy({
    required this.title,
    this.body,
    this.recoveryHint = ErrorRecovery.none,
  });

  final String title;
  final String? body;
  final ErrorRecovery recoveryHint;
}

/// What the user can do about an error.
///
/// The screen decides how to present it; this says which affordance is
/// appropriate, so a sold-out bag never gets a bare "Try again" button.
enum ErrorRecovery {
  none,
  retry,
  seeAlternatives,
  reReserve,
  changePaymentMethod,
  resolveBlockers,
  signIn,
  update,
  contactSupport,
}

/// **Stage 2 of the two-stage error mapping** (Phase 8 §8.5).
///
/// Stage 1 lives in `data`: HTTP status plus the Phase 7 §7.1.5 `code` becomes a
/// typed [AppException] carrying no strings. Stage 2 — here — turns that type
/// into authored, localised copy.
///
/// That split is what lets §C5 ("never surface a raw server message") and the
/// i18n requirement be satisfied by one structure rather than fighting each
/// other. And the exception's *typed details* are what make §C5's
/// **domain-specific** copy possible: [BagSoldOutException] carries the
/// alternatives the screen must offer, so we can say "this bag just went — here
/// are three others" instead of "error 409".
///
/// ## The switch is exhaustive on purpose
///
/// [AppException] is a sealed hierarchy, so Dart requires every subtype to be
/// handled. Adding a new error type is therefore a **compile error until its
/// copy exists** — which is a far stronger guarantee than a review checklist,
/// and the mechanism by which a generic "Something went wrong" can never quietly
/// become the fallback for a real product situation.
abstract final class ErrorCopyMapper {
  /// Resolves copy for [error].
  ///
  /// [refundSlaMinDays] / [refundSlaMaxDays] come from `policyValues` (A19), so
  /// the refund window stated here can never drift from the one stated at
  /// checkout or in the legal documents.
  static ErrorCopy resolve(
    AppException error,
    AppLocalizations l10n, {
    required int refundSlaMinDays,
    required int refundSlaMaxDays,
  }) {
    return switch (error) {
      // ---- Transport -------------------------------------------------------
      NetworkException() => ErrorCopy(
        title: l10n.errorOfflineTitle,
        body: l10n.errorOfflineBody,
        recoveryHint: ErrorRecovery.retry,
      ),
      RequestTimeoutException() => ErrorCopy(
        title: l10n.errorTimeoutTitle,
        body: l10n.errorTimeoutBody,
        recoveryHint: ErrorRecovery.retry,
      ),
      ServerException() => ErrorCopy(
        title: l10n.errorServerTitle,
        body: l10n.errorServerBody,
        recoveryHint: ErrorRecovery.retry,
      ),
      NotFoundException() => ErrorCopy(
        title: l10n.notFoundTitle,
        body: l10n.notFoundBody,
      ),

      // ---- Lifecycle -------------------------------------------------------
      SessionExpiredException() => ErrorCopy(
        title: l10n.sessionExpiredTitle,
        body: l10n.sessionExpiredBody,
        recoveryHint: ErrorRecovery.signIn,
      ),
      ForceUpdateException() => ErrorCopy(
        title: l10n.forceUpdateTitle,
        body: l10n.forceUpdateBody,
        recoveryHint: ErrorRecovery.update,
      ),
      final MaintenanceException e => ErrorCopy(
        title: l10n.maintenanceTitle,
        body: e.etaAt == null
            ? l10n.maintenanceBody
            // Preferred whenever known — an unspecified outage reads as
            // abandonment (§5a.10).
            : l10n.maintenanceBodyWithEta(Fmt.expectedBy(e.etaAt!)),
        recoveryHint: ErrorRecovery.retry,
      ),

      // ---- Validation ------------------------------------------------------
      // Field errors render inline at the offending field, never as a banner
      // (§C5), so this path is a fallback for a malformed response only.
      ValidationException() => ErrorCopy(title: l10n.errorServerTitle),

      // ---- OTP -------------------------------------------------------------
      final OtpInvalidException e => ErrorCopy(
        title: l10n.otpInvalidTitle,
        body: l10n.otpAttemptsLeft(e.attemptsRemaining),
      ),
      OtpExpiredException() => ErrorCopy(
        title: l10n.otpExpiredTitle,
        body: l10n.otpExpiredBody,
        recoveryHint: ErrorRecovery.retry,
      ),
      final OtpAttemptsExhaustedException e => ErrorCopy(
        title: l10n.otpExhaustedTitle,
        body: l10n.otpExhaustedBody(Fmt.countdown(e.retryAfter)),
      ),
      final OtpRateLimitedException e => ErrorCopy(
        title: l10n.otpRateLimitedTitle,
        body: l10n.otpRateLimitedBody(Fmt.countdown(e.retryAfter)),
      ),
      OtpChannelUnavailableException() => ErrorCopy(
        title: l10n.otpSmsFailedTitle,
        body: l10n.otpSmsFailedBody,
      ),

      // ---- Domain conflicts ------------------------------------------------
      // Every one of these gets specific copy. §C5 forbids a generic 409
      // handler: each is a distinct product situation with a distinct remedy,
      // and collapsing them throws away the only information the user needs.
      BagSoldOutException() => ErrorCopy(
        title: l10n.bagSoldOutTitle,
        body: l10n.bagSoldOutBody,
        recoveryHint: ErrorRecovery.seeAlternatives,
      ),
      BagWithdrawnException() => ErrorCopy(
        title: l10n.bagWithdrawnTitle,
        body: l10n.bagWithdrawnBody,
        recoveryHint: ErrorRecovery.seeAlternatives,
      ),
      BagWindowClosedException() => ErrorCopy(
        title: l10n.bagWindowClosedTitle,
        body: l10n.bagWindowClosedBody,
        recoveryHint: ErrorRecovery.seeAlternatives,
      ),
      HoldExpiredException() => ErrorCopy(
        title: l10n.cartHoldExpiredTitle,
        // "may still be available" — promising availability we have not
        // revalidated (R2) would fail twice in a row.
        body: l10n.cartHoldExpiredBody(9),
        recoveryHint: ErrorRecovery.reReserve,
      ),
      final PurchaseCapExceededException e => ErrorCopy(
        title: l10n.purchaseCapTitle(2),
        body: l10n.purchaseCapBody(e.remainingAllowance),
      ),
      final HoldConflictOtherMerchantException e => ErrorCopy(
        title: l10n.cartReplaceTitle(e.existingMerchantName),
        body: l10n.cartReplaceBody,
      ),
      final CancellationWindowPassedException e => ErrorCopy(
        title: l10n.cancellationTooLateTitle,
        body: l10n.cancellationTooLateBody(Fmt.expectedBy(e.cutoffAt)),
      ),
      ReviewAlreadyExistsException() => ErrorCopy(
        title: l10n.reviewAlreadyExists,
      ),
      NotificationNotDismissibleException() => ErrorCopy(
        title: l10n.notificationNotDismissibleTitle,
        body: l10n.notificationNotDismissibleBody,
      ),
      AccountDeletionBlockedException() => ErrorCopy(
        title: l10n.deletionBlockedTitle,
        recoveryHint: ErrorRecovery.resolveBlockers,
      ),

      // ---- Payment ---------------------------------------------------------
      final PaymentFailedException e => ErrorCopy(
        title: l10n.paymentFailedTitle,
        body:
            '${_paymentReason(e.reason, l10n)} '
            '${_chargeStatement(e.chargeState, l10n, refundSlaMinDays, refundSlaMaxDays)}',
        recoveryHint: ErrorRecovery.changePaymentMethod,
      ),
      final PaymentHoldCollisionException e => ErrorCopy(
        title: l10n.holdCollisionTitle,
        body: l10n.holdCollisionBody(Fmt.money(e.refundAmount)),
      ),
    };
  }

  /// Maps a gateway reason code to authored copy.
  ///
  /// Raw gateway strings never reach the user (§C5). An unrecognised code falls
  /// back to a neutral statement rather than leaking the code itself.
  static String _paymentReason(String reason, AppLocalizations l10n) =>
      switch (reason) {
        'declined' => l10n.paymentReasonDeclined,
        'insufficient_funds' => l10n.paymentReasonInsufficientFunds,
        'cancelled' => l10n.paymentReasonCancelled,
        'timeout' => l10n.paymentReasonTimeout,
        _ => l10n.paymentReasonUnknown,
      };

  /// **Amendment A13** — one of two authored variants, never a guess.
  ///
  /// [ChargeState.charged] uses the uncertain wording deliberately: if a debit
  /// definitely occurred on a payment that failed, the user is owed a refund and
  /// the honest statement is the same one they need to hear.
  ///
  /// Defaulting to the reassuring variant when unsure is tempting and wrong. A
  /// user told they were not charged who then sees a debit escalates to their
  /// bank and to a public review; a user told a refund may be coming who sees
  /// nothing debited has lost nothing.
  static String _chargeStatement(
    ChargeState state,
    AppLocalizations l10n,
    int minDays,
    int maxDays,
  ) => switch (state) {
    ChargeState.notCharged => l10n.chargeStateNotCharged,
    ChargeState.charged ||
    ChargeState.uncertain => l10n.chargeStateUncertain(minDays, maxDays),
  };
}
