/// Trend-chart helpers — orders carry no separate "placed at" timestamp,
/// so callers bucket by whatever date field stands in for it (typically a
/// pickup window's start date).
library;

/// The last [n] calendar days up to and including [today], oldest first.
List<DateTime> lastNDays(DateTime today, int n) => [
  for (var i = n - 1; i >= 0; i--) dateOnly(today).subtract(Duration(days: i)),
];

/// Every calendar day from [start] to [end] inclusive, oldest first. Swaps
/// the two if given in reverse order, so a caller never has to check.
List<DateTime> daysInRange(DateTime start, DateTime end) {
  var from = dateOnly(start);
  var to = dateOnly(end);
  if (from.isAfter(to)) {
    final swap = from;
    from = to;
    to = swap;
  }
  final days = <DateTime>[];
  for (var d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) {
    days.add(d);
  }
  return days;
}

/// Strips the time-of-day component, for use as a bucket key.
DateTime dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);
