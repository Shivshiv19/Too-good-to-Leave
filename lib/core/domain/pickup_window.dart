import 'package:surplus_marketplace/core/domain/clock.dart';

/// How urgent a pickup window is *right now*.
///
/// Derived, never stored (Phase 2 §2.2). The three active states map onto
/// deliberately distinct colours (§6.2.7) — and the mapping is semantic rather
/// than a heat ramp: [openNow] is **good** news and is rendered with the
/// success role, not a warning.
enum WindowUrgency {
  /// Window has not opened yet.
  upcoming,

  /// Collectable now, with comfortable time remaining.
  openNow,

  /// Open, with less than [PickupWindow.closingSoonThreshold] remaining.
  closingSoon,

  /// Window has passed.
  closed,
}

/// The interval during which an order may be collected.
///
/// Times carry an explicit offset on the wire (Phase 7 §7.1.3) because a pickup
/// window is wall-clock-meaningful to a person standing outside a shop.
final class PickupWindow {
  /// Creates a window.
  ///
  /// Asserts invariant **I4** (Phase 2 §2.1): a window must have positive
  /// duration.
  PickupWindow({required this.startAt, required this.endAt})
    : assert(
        startAt.isBefore(endAt),
        'A pickup window must start before it ends.',
      );

  /// When collection becomes possible.
  final DateTime startAt;

  /// When collection stops being possible.
  final DateTime endAt;

  /// Remaining-time threshold below which an open window is [closingSoon].
  ///
  /// 30 minutes, per §5d.3. Distinct from the T-45min `pickupClosingSoon` push
  /// (§2.6): the notification fires earlier than the UI escalates, so a user
  /// who acts on the alert does not arrive to find the screen already red.
  static const closingSoonThreshold = Duration(minutes: 30);

  Duration get duration => endAt.difference(startAt);

  /// Urgency as of [clock]'s current instant.
  WindowUrgency urgencyAt(Clock clock) {
    final now = clock.now();
    if (now.isBefore(startAt)) return WindowUrgency.upcoming;
    if (!now.isBefore(endAt)) return WindowUrgency.closed;
    return endAt.difference(now) <= closingSoonThreshold
        ? WindowUrgency.closingSoon
        : WindowUrgency.openNow;
  }

  bool isOpenAt(Clock clock) {
    final urgency = urgencyAt(clock);
    return urgency == WindowUrgency.openNow ||
        urgency == WindowUrgency.closingSoon;
  }

  bool hasClosedAt(Clock clock) => urgencyAt(clock) == WindowUrgency.closed;

  /// Time until the window opens, or `null` once it has.
  Duration? timeUntilOpenAt(Clock clock) {
    final now = clock.now();
    return now.isBefore(startAt) ? startAt.difference(now) : null;
  }

  /// Time until the window closes, or `null` once it has.
  ///
  /// This is the value the pickup countdown renders (§5d.3), with tabular
  /// figures so it does not jitter as it ticks.
  Duration? timeUntilCloseAt(Clock clock) {
    final now = clock.now();
    return now.isBefore(endAt) ? endAt.difference(now) : null;
  }

  /// Whether this window closes at or before [safeUntil].
  ///
  /// Invariant **I1** (Phase 2 §2.1) — FSSAI: food may not be sold for
  /// collection after its safe-consumption deadline. Enforced in
  /// `SurpriseBag`'s constructor so a violating listing is unconstructable;
  /// exposed here so the rule lives with the type that expresses it.
  bool isWithinSafetyDeadline(DateTime safeUntil) => !endAt.isAfter(safeUntil);

  @override
  bool operator ==(Object other) =>
      other is PickupWindow &&
      other.startAt.isAtSameMomentAs(startAt) &&
      other.endAt.isAtSameMomentAs(endAt);

  @override
  int get hashCode =>
      Object.hash(startAt.microsecondsSinceEpoch, endAt.microsecondsSinceEpoch);

  @override
  String toString() => 'PickupWindow($startAt → $endAt)';
}
