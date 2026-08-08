import 'package:flutter_test/flutter_test.dart';
import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/domain/pickup_window.dart';

void main() {
  // A fixed evening, matching the late supply peak we designed for
  // (Phase 1 §3.8): bakeries and sweet shops clear around 8–10 pm.
  final windowStart = DateTime(2026, 7, 26, 20);
  final windowEnd = DateTime(2026, 7, 26, 22);
  final window = PickupWindow(startAt: windowStart, endAt: windowEnd);

  PickupWindow makeWindow() =>
      PickupWindow(startAt: windowStart, endAt: windowEnd);

  group('invariants', () {
    test('rejects a window that ends before it starts (I4)', () {
      expect(
        () => PickupWindow(startAt: windowEnd, endAt: windowStart),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects a zero-length window', () {
      expect(
        () => PickupWindow(startAt: windowStart, endAt: windowStart),
        throwsA(isA<AssertionError>()),
      );
    });

    test('duration is the interval length', () {
      expect(makeWindow().duration, const Duration(hours: 2));
    });
  });

  group('urgency (§6.2.7)', () {
    test('is upcoming before the window opens', () {
      final clock = FixedClock(DateTime(2026, 7, 26, 19));
      expect(window.urgencyAt(clock), WindowUrgency.upcoming);
      expect(window.isOpenAt(clock), isFalse);
    });

    test('is openNow at the moment it opens', () {
      final clock = FixedClock(windowStart);
      expect(window.urgencyAt(clock), WindowUrgency.openNow);
      expect(window.isOpenAt(clock), isTrue);
    });

    test('is openNow with more than 30 minutes remaining', () {
      final clock = FixedClock(DateTime(2026, 7, 26, 21, 29));
      expect(window.urgencyAt(clock), WindowUrgency.openNow);
    });

    test('becomes closingSoon at exactly 30 minutes remaining', () {
      // The threshold is inclusive. The T-45min `pickupClosingSoon` push (§2.6)
      // deliberately fires EARLIER than this UI escalation, so a user who acts
      // on the notification does not arrive to find the screen already red.
      final clock = FixedClock(DateTime(2026, 7, 26, 21, 30));
      expect(window.urgencyAt(clock), WindowUrgency.closingSoon);
      expect(window.isOpenAt(clock), isTrue);
    });

    test('is closed at the moment the window ends', () {
      final clock = FixedClock(windowEnd);
      expect(window.urgencyAt(clock), WindowUrgency.closed);
      expect(window.isOpenAt(clock), isFalse);
      expect(window.hasClosedAt(clock), isTrue);
    });

    test('urgency progresses as the clock advances', () {
      // The behaviour the injected Clock exists for: a two-hour window is
      // traversed instantly instead of waited out (§7.10).
      final clock = FixedClock(DateTime(2026, 7, 26, 19, 30));
      expect(window.urgencyAt(clock), WindowUrgency.upcoming);

      clock.advance(const Duration(minutes: 45)); // 20:15
      expect(window.urgencyAt(clock), WindowUrgency.openNow);

      clock.advance(const Duration(minutes: 80)); // 21:35
      expect(window.urgencyAt(clock), WindowUrgency.closingSoon);

      clock.advance(const Duration(minutes: 30)); // 22:05
      expect(window.urgencyAt(clock), WindowUrgency.closed);
    });
  });

  group('remaining time', () {
    test('reports time until open, then null once open', () {
      final before = FixedClock(DateTime(2026, 7, 26, 19, 30));
      expect(window.timeUntilOpenAt(before), const Duration(minutes: 30));
      expect(window.timeUntilOpenAt(FixedClock(windowStart)), isNull);
    });

    test('reports time until close, then null once closed', () {
      final during = FixedClock(DateTime(2026, 7, 26, 21));
      expect(window.timeUntilCloseAt(during), const Duration(hours: 1));
      expect(window.timeUntilCloseAt(FixedClock(windowEnd)), isNull);
    });
  });

  group('FSSAI safety deadline (invariant I1)', () {
    test('accepts a window that closes before the safe-until deadline', () {
      expect(
        window.isWithinSafetyDeadline(DateTime(2026, 7, 26, 23)),
        isTrue,
      );
    });

    test('accepts a window that closes exactly at the deadline', () {
      expect(window.isWithinSafetyDeadline(windowEnd), isTrue);
    });

    test('rejects a window that closes after the deadline', () {
      // FSSAI: food may not be sold for collection after its safe-consumption
      // deadline. Enforced in SurpriseBag's constructor so a violating listing
      // is unconstructable — this asserts the rule the constructor relies on.
      expect(
        window.isWithinSafetyDeadline(DateTime(2026, 7, 26, 21)),
        isFalse,
      );
    });
  });

  group('equality', () {
    test('is by value on both instants', () {
      expect(makeWindow(), window);
      expect(makeWindow().hashCode, window.hashCode);
      expect(
        PickupWindow(
          startAt: windowStart,
          endAt: windowEnd.add(
            const Duration(minutes: 1),
          ),
        ),
        isNot(window),
      );
    });
  });
}
