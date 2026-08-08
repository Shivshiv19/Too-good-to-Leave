/// One weekday's operating hours.
final class DayHours {
  const DayHours({required this.isOpen, this.openHour = 9, this.closeHour = 21});

  final bool isOpen;

  /// 24-hour clock, whole hours only — enough precision for "what hours is
  /// this shop generally open," which is what this screen is for; a bag's
  /// own pickup window (set per-listing) is where exact minute-level timing
  /// actually matters.
  final int openHour;
  final int closeHour;

  DayHours copyWith({bool? isOpen, int? openHour, int? closeHour}) =>
      DayHours(
        isOpen: isOpen ?? this.isOpen,
        openHour: openHour ?? this.openHour,
        closeHour: closeHour ?? this.closeHour,
      );

  Map<String, dynamic> toJson() => {
    'isOpen': isOpen,
    'openHour': openHour,
    'closeHour': closeHour,
  };

  factory DayHours.fromJson(Map<String, dynamic> json) => DayHours(
    isOpen: json['isOpen'] as bool,
    openHour: json['openHour'] as int,
    closeHour: json['closeHour'] as int,
  );
}

/// Monday-first weekly hours — informational only (shown on the shop's
/// account, not enforced anywhere against listings or pickups). Real
/// enforcement would mean cross-checking every bag's pickup window against
/// these hours, which is a real feature but a bigger one than "settings"
/// scope covers here.
final class StoreHours {
  const StoreHours({required this.days});

  factory StoreHours.defaults() => const StoreHours(
    days: [
      DayHours(isOpen: true),
      DayHours(isOpen: true),
      DayHours(isOpen: true),
      DayHours(isOpen: true),
      DayHours(isOpen: true),
      DayHours(isOpen: true),
      DayHours(isOpen: false),
    ],
  );

  /// Index 0 = Monday .. index 6 = Sunday.
  final List<DayHours> days;

  StoreHours withDay(int index, DayHours hours) => StoreHours(
    days: [for (var i = 0; i < days.length; i++) i == index ? hours : days[i]],
  );

  Map<String, dynamic> toJson() => {
    'days': days.map((d) => d.toJson()).toList(),
  };

  factory StoreHours.fromJson(Map<String, dynamic> json) => StoreHours(
    days: (json['days'] as List)
        .cast<Map<String, dynamic>>()
        .map(DayHours.fromJson)
        .toList(),
  );
}
