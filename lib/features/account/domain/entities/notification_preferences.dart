/// §5f.4 — only the **togglable** notification types are represented here.
/// Order-update/transactional types (`orderConfirmed`, `paymentFailed`,
/// `merchantCancelled`, refund events, pickup reminders) are always on and
/// deliberately have no field — §3.5 obligation 2 requires them unmutable
/// by a marketing opt-out, and a field a client could theoretically flip
/// would invite exactly the bug that obligation forbids.
final class NotificationPreferences {
  const NotificationPreferences({
    required this.newBagsNearby,
    required this.watchedMerchantListed,
    required this.rateYourPickup,
  });

  final bool newBagsNearby;
  final bool watchedMerchantListed;
  final bool rateYourPickup;

  NotificationPreferences copyWith({
    bool? newBagsNearby,
    bool? watchedMerchantListed,
    bool? rateYourPickup,
  }) => NotificationPreferences(
    newBagsNearby: newBagsNearby ?? this.newBagsNearby,
    watchedMerchantListed: watchedMerchantListed ?? this.watchedMerchantListed,
    rateYourPickup: rateYourPickup ?? this.rateYourPickup,
  );
}
