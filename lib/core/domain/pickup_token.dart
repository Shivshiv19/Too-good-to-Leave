/// The pickup credential (Phase 2 §2.1, amendment A1, §7.6 wire shape).
///
/// **A1's three layers**, in the order the pickup screen prefers them:
///
/// 1. [rotatingPayload] — signed, rotates roughly every 60 s. Requires
///    connectivity to refresh.
/// 2. [offlineToken] — a window-duration signed token, fetched and cached at
///    order **confirmation**, not at the shop. That ordering is the whole
///    point of A1: the device must already hold a valid token before it
///    reaches a basement counter with no signal.
/// 3. [fallbackCode] — 6-char, unambiguous alphabet (excludes `0/O`, `1/I/L`)
///    — read aloud by a stranger at the counter when neither QR layer
///    scans. Always present, never hidden behind a "can't scan?" link
///    (§5d.3).
final class PickupToken {
  const PickupToken({
    required this.rotatingPayload,
    required this.rotationExpiresAt,
    required this.offlineToken,
    required this.offlineTokenValidUntil,
    required this.fallbackCode,
  });

  final String rotatingPayload;
  final DateTime rotationExpiresAt;
  final String offlineToken;
  final DateTime offlineTokenValidUntil;
  final String fallbackCode;
}
