import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/domain/pickup_window.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/core/utils/formatters.dart';

/// §5d.1/§5d.3's shared window-state copy — *"Opens in 45 min"* / *"Collect
/// now — closes in 1h 12m"* / *"Closing soon — 22 min left"*.
///
/// One function because the hero card, the order list row, and the pickup
/// screen all render the same state off the same [PickupWindow.urgencyAt]
/// derivation; three independent copies would drift.
String windowStateLabel(
  PickupWindow window,
  Clock clock,
  AppLocalizations l10n,
) {
  final urgency = window.urgencyAt(clock);
  return switch (urgency) {
    WindowUrgency.upcoming => l10n.pickupOpensIn(
      Fmt.countdown(window.timeUntilOpenAt(clock)!),
    ),
    WindowUrgency.openNow => l10n.pickupCollectNow(
      Fmt.countdown(window.timeUntilCloseAt(clock)!),
    ),
    WindowUrgency.closingSoon => l10n.pickupClosingSoon(
      Fmt.countdown(window.timeUntilCloseAt(clock)!),
    ),
    WindowUrgency.closed => l10n.orderExpiredTitle,
  };
}
