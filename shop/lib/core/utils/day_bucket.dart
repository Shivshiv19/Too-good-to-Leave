/// Trend-chart helpers — orders carry no separate "placed at" timestamp,
/// so callers bucket by whatever date field stands in for it (typically a
/// pickup window's start date).
library;

/// The last [n] calendar days up to and including [today], oldest first.
List<DateTime> lastNDays(DateTime today, int n) => [
  for (var i = n - 1; i >= 0; i--) dateOnly(today).subtract(Duration(days: i)),
];

/// Strips the time-of-day component, for use as a bucket key.
DateTime dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);
