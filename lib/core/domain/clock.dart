/// Source of the current time.
///
/// Every read of "now" in the application goes through a [Clock] (Phase 7
/// §7.10). The product's core mechanic is a countdown — pickup windows, cart
/// holds, token validity, OTP resend cooldowns — and none of it is testable if
/// the code calls `DateTime.now()` directly.
///
/// With injection, a test asserts that a window is `closingSoon` at T-29
/// minutes instantly, instead of waiting. Golden tests are also stable, because
/// a rendered countdown is deterministic.
abstract interface class Clock {
  /// The current instant.
  DateTime now();
}

/// Wall-clock time. The binding used in every flavour.
final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// A clock frozen at a chosen instant, advanced explicitly.
///
/// Test-only, but lives in `core/domain` rather than `test/` because the fake
/// repositories (Phase 7 §7.10) use it to model hold expiry deterministically
/// in the dev flavour's scenario runner.
final class FixedClock implements Clock {
  FixedClock(this._instant);

  DateTime _instant;

  @override
  DateTime now() => _instant;

  /// Moves time forward by [duration].
  void advance(Duration duration) => _instant = _instant.add(duration);

  /// Jumps to an absolute instant.
  void set(DateTime instant) => _instant = instant;
}
