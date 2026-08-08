import 'package:flutter_test/flutter_test.dart';
import 'package:surplus_marketplace/core/domain/money.dart';

void main() {
  group('Money construction', () {
    test('stores integer paise exactly', () {
      expect(const Money(12000).amountInPaise, 12000);
      expect(const Money.rupees(120).amountInPaise, 12000);
      expect(const Money.zero().isZero, isTrue);
    });

    test('decomposes whole and sub units', () {
      const m = Money(12050);
      expect(m.wholeUnits, 120);
      expect(m.subUnits, 50);
      expect(m.hasSubUnits, isTrue);
      expect(const Money(12000).hasSubUnits, isFalse);
    });

    test('sub units are absolute for negative amounts', () {
      expect(const Money(-12050).subUnits, 50);
      expect(const Money(-12050).isNegative, isTrue);
    });
  });

  group('Money arithmetic', () {
    test('adds and subtracts without drift', () {
      // The reason Money holds integer paise rather than a double: in binary
      // floating point 0.1 + 0.2 != 0.3, and a marketplace whose displayed total
      // disagrees with the amount it charges has an unrecoverable bug.
      var total = const Money.zero();
      for (var i = 0; i < 3; i++) {
        total = total + const Money(10);
      }
      expect(total.amountInPaise, 30);
      expect(total, const Money(30));
    });

    test('scales by integer quantity', () {
      expect(const Money(12000) * 3, const Money(36000));
    });

    test('negates', () {
      expect(-const Money(12000), const Money(-12000));
    });

    test('compares', () {
      expect(const Money(100) < const Money(200), isTrue);
      expect(const Money(200) >= const Money(200), isTrue);
      expect(const Money(300) > const Money(200), isTrue);
    });
  });

  group('discountPercentAgainst', () {
    test('truncates toward zero', () {
      // ₹120 against ₹350 saves ₹230, which is 65.7% — reported as 65.
      expect(
        const Money.rupees(120).discountPercentAgainst(
          const Money.rupees(350),
        ),
        65,
      );
    });

    test('returns zero when there is no saving', () {
      expect(
        const Money.rupees(350).discountPercentAgainst(
          const Money.rupees(350),
        ),
        0,
      );
      expect(
        const Money.rupees(400).discountPercentAgainst(
          const Money.rupees(350),
        ),
        0,
      );
    });

    test(
      'returns zero for a non-positive original, rather than dividing by it',
      () {
        expect(
          const Money.rupees(120).discountPercentAgainst(const Money.zero()),
          0,
        );
      },
    );
  });

  group('equality', () {
    test('is by value including currency', () {
      expect(const Money(12000), const Money(12000));
      expect(const Money(12000).hashCode, const Money(12000).hashCode);
      expect(const Money(12000) == const Money(12001), isFalse);
    });
  });
}
