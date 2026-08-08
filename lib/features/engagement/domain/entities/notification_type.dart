/// Phase 2 §2.6's notification inventory.
enum NotificationType {
  newBagsNearby('new_bags_nearby'),
  watchedMerchantListed('watched_merchant_listed'),
  pickupWindowOpening('pickup_window_opening'),
  pickupClosingSoon('pickup_closing_soon'),
  orderConfirmed('order_confirmed'),
  paymentFailed('payment_failed'),
  merchantCancelled('merchant_cancelled'),
  refundInitiated('refund_initiated'),
  refundCompleted('refund_completed'),
  rateYourPickup('rate_your_pickup');

  const NotificationType(this.wireValue);

  final String wireValue;

  static NotificationType fromWire(String value) => switch (value) {
    'new_bags_nearby' => NotificationType.newBagsNearby,
    'watched_merchant_listed' => NotificationType.watchedMerchantListed,
    'pickup_window_opening' => NotificationType.pickupWindowOpening,
    'pickup_closing_soon' => NotificationType.pickupClosingSoon,
    'order_confirmed' => NotificationType.orderConfirmed,
    'payment_failed' => NotificationType.paymentFailed,
    'merchant_cancelled' => NotificationType.merchantCancelled,
    'refund_initiated' => NotificationType.refundInitiated,
    'refund_completed' => NotificationType.refundCompleted,
    // Conservative fallback — a prompt-class nudge is the lowest-stakes
    // misclassification if the wire ever sends something unrecognised.
    _ => NotificationType.rateYourPickup,
  };
}
