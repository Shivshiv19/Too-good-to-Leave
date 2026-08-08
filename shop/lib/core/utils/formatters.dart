import 'package:intl/intl.dart';
import 'package:too_good_to_leave_shop/core/domain/clock.dart';
import 'package:too_good_to_leave_shop/core/domain/money.dart';
import 'package:too_good_to_leave_shop/core/domain/pickup_window.dart';

/// The **only** site in the application permitted to format currency, dates, or
/// durations for display (§C7).
///
/// Centralised because `en_IN` conventions are easy to get subtly wrong and
/// impossible to fix consistently once scattered: Indian digit grouping is
/// `₹1,00,000`, not `₹100,000`.
abstract final class Fmt {
  static final _inrWhole = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static final _inrWithPaise = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final _timeOfDay = DateFormat('h:mm a', 'en_IN');
  static final _timeOfDayCompact = DateFormat('h a', 'en_IN');
  static final _dayMonth = DateFormat('d MMM', 'en_IN');
  static final _dayMonthTime = DateFormat('d MMM, h:mm a', 'en_IN');

  /// Formats [money] for display.
  ///
  /// Decimals appear only when the amount has a non-zero paise component —
  /// Indian prices are conventionally whole rupees, and `₹120.00` reads as
  /// machine output.
  static String money(Money money) {
    final rupees = money.amountInPaise / 100;
    return money.hasSubUnits
        ? _inrWithPaise.format(rupees)
        : _inrWhole.format(rupees);
  }

  /// Screen-reader form of a struck-through original price.
  ///
  /// **The qualifier is mandatory.** Announced as a bare number, a struck price
  /// sounds like *the* price (§5b.1) — the strikethrough is purely visual and
  /// carries no meaning to a screen reader.
  static String wasPriceSemantics(Money original) => 'was ${money(original)}';

  /// A pickup window as a single line — `Today, 8:00 pm – 10:00 pm`.
  ///
  /// Day context uses "Today"/"Tomorrow" inside 48 hours (§C7), because a user
  /// deciding whether they can collect something thinks in those terms, not in
  /// dates.
  static String pickupWindow(PickupWindow window, Clock clock) {
    final prefix = _dayContext(window.startAt, clock);
    final start = _timeOfDay.format(window.startAt);
    final end = _timeOfDay.format(window.endAt);
    return '$prefix, $start – $end';
  }

  /// Compact window for dense surfaces — `8 – 10 pm`.
  static String pickupWindowCompact(PickupWindow window) =>
      '${_timeOfDayCompact.format(window.startAt)} – '
      '${_timeOfDayCompact.format(window.endAt)}';

  /// A single instant's time of day — `8:00 pm`. For copy that names a
  /// pickup window's start and end as two separate placeholders (§5c.2's
  /// terms block), rather than [pickupWindow]'s single combined string.
  static String timeOfDay(DateTime instant) => _timeOfDay.format(instant);

  /// Visual countdown — `1h 12m`, `22m`, `45s`.
  ///
  /// Rendered with the `countdown` type role, which uses tabular figures so the
  /// text does not jitter as it ticks (§6.3.2).
  static String countdown(Duration remaining) {
    if (remaining.isNegative || remaining == Duration.zero) return '0m';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    if (remaining.inMinutes > 0) return '${remaining.inMinutes}m';
    return '${remaining.inSeconds}s';
  }

  /// Screen-reader form of a countdown.
  ///
  /// Spelled out, because `1h 12m` is not reliably pronounced. Announced
  /// **politely and only at thresholds** — a per-second live region is unusable
  /// (§5c.1, §5d.3).
  static String countdownSemantics(Duration remaining) {
    if (remaining.isNegative || remaining == Duration.zero) {
      return 'no time remaining';
    }
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    final parts = <String>[
      if (hours > 0) '$hours ${hours == 1 ? 'hour' : 'hours'}',
      if (minutes > 0) '$minutes ${minutes == 1 ? 'minute' : 'minutes'}',
      if (hours == 0 && minutes == 0) '${remaining.inSeconds} seconds',
    ];
    return '${parts.join(' ')} remaining';
  }

  /// Relative timestamp for notification and review lists — `2h ago`.
  static String relativeTime(DateTime instant, Clock clock) {
    final diff = clock.now().difference(instant);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return _dayMonth.format(instant);
  }

  /// Absolute timestamp, always exposed alongside [relativeTime] in semantics.
  ///
  /// `2h ago` is unhelpful to someone returning after several days and
  /// ambiguous when read aloud (§5e.1), so the screen-reader label carries the
  /// absolute time even where the visual shows the relative one.
  static String absoluteTime(DateTime instant, Clock clock) {
    final prefix = _dayContext(instant, clock);
    return prefix == _dayMonth.format(instant)
        ? _dayMonthTime.format(instant)
        : '$prefix at ${_timeOfDay.format(instant)}';
  }

  /// A distance in metres, rendered the way a customer decides "is this
  /// walkable" — `850 m` below 1 km, `1.2 km` above it (§5b.1's bag-card
  /// label).
  static String distance(int metres) {
    if (metres < 1000) return '$metres m';
    final km = metres / 1000;
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }

  /// A phone number with its middle digits hidden — `+91 ******78`
  /// (§5f.1's profile header, §5a.7's OTP-sent-to line).
  static String maskedPhone(String phoneE164) {
    if (phoneE164.length < 4) return phoneE164;
    return '+91 ${'*' * 6}${phoneE164.substring(phoneE164.length - 2)}';
  }

  /// An expected-by date for a refund — `by 2 Aug`.
  ///
  /// §5d.4 forbids the word "processing" without a date, because an open-ended
  /// wait is what converts a waiting customer into one who believes they have
  /// been robbed.
  static String expectedBy(DateTime instant) =>
      'by ${_dayMonth.format(instant)}';

  static String _dayContext(DateTime instant, Clock clock) {
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(instant.year, instant.month, instant.day);
    final delta = target.difference(today).inDays;
    return switch (delta) {
      0 => 'Today',
      1 => 'Tomorrow',
      -1 => 'Yesterday',
      _ => _dayMonth.format(instant),
    };
  }
}
