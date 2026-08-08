import 'package:surplus_marketplace/core/domain/grievance_officer.dart';

/// Commercial policy numbers, sourced from `GET /v1/config` (Phase 7 §7.3).
///
/// **Amendment A19.** The checkout terms block (§5c.2), the cancel dialog
/// (§5d.5), and the rendered legal documents (§5f.9) all read these same
/// values. No policy number is authored twice, so the three surfaces cannot
/// silently drift into an unfair-terms exposure — one config fetch, one
/// source of truth, three renderings.
final class PolicyValues {
  const PolicyValues({
    required this.cancellationCutoffBeforeWindow,
    required this.noShowRefundPolicy,
    required this.refundSlaWorkingDays,
    required this.grievanceSla,
    required this.purchaseCapPerListing,
    required this.holdTtl,
    required this.grievanceOfficer,
  });

  /// Amendment A15 — how long before a pickup window opens that a free
  /// cancellation is still allowed. **Unsigned as of Phase 7** (§7.3 "Open"),
  /// so this value is read from config rather than hardcoded specifically so
  /// the eventual sign-off is a data change, not a release.
  final Duration cancellationCutoffBeforeWindow;

  /// Server-defined policy key for a missed pickup — e.g. `"none"`. Left as an
  /// opaque string rather than an enum: the wire has only ever specified one
  /// value, and inventing unspecified variants would be speculative. Rendered
  /// through the copy deck's authored strings (§C5), never shown raw.
  final String noShowRefundPolicy;

  /// Working-day range for a refund to land, e.g. 3–7.
  final ({int min, int max}) refundSlaWorkingDays;

  /// How long the grievance officer has to respond (§5f.9).
  final Duration grievanceSla;

  /// Amendment A9 — per-listing purchase cap for a single customer.
  final int purchaseCapPerListing;

  /// How long a cart hold survives before releasing (§2.2, A2).
  final Duration holdTtl;

  /// **Amendment A19** — the one source for the grievance officer's
  /// identity, read by both Contact Us (§5f.8) and the Legal grievance
  /// document (§5f.9).
  final GrievanceOfficer grievanceOfficer;
}
