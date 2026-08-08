/// Currencies the platform can represent.
///
/// Single-country in V1 (Phase 1 assumption A3). The type exists so that a
/// second currency is an additive change rather than a search-and-replace.
enum Currency {
  inr('INR', '₹');

  const Currency(this.code, this.symbol);

  /// ISO 4217 code, as it appears on the wire (Phase 7 §7.1.3).
  final String code;

  /// Display symbol. Presentation only — see `core/utils/formatters.dart`.
  final String symbol;

  /// Tolerant decoder: an unknown wire value falls back rather than throwing
  /// (Phase 7 §7.1.4).
  static Currency fromCode(String code) => Currency.values.firstWhere(
    (c) => c.code == code,
    orElse: () => Currency.inr,
  );
}

/// An exact monetary amount.
///
/// Held as **integer paise**, never a double (Phase 2 §2.1). Floating-point
/// currency is a defect class, not a style preference: 0.1 + 0.2 != 0.3 in
/// binary floating point, and a marketplace that rounds a customer's total
/// differently from the amount it charges has an unrecoverable bug.
///
/// `Money` carries **no formatting**. Rendering — including `en_IN` grouping
/// (`₹1,00,000`) — lives in `core/utils/formatters.dart`, which is the only
/// site permitted to format currency (§C7).
///
/// ## Rule R1
///
/// Arithmetic on `Money` is legal **only inside `core/domain`**. Feature code
/// must never compute, sum, or adjust a monetary value; it renders a
/// server-supplied [PriceBreakdown] as received. The operators below exist for
/// the domain's own use (and for the fake repositories, which stand in for the
/// server) — not as a convenience for widgets.
///
/// The `no_money_arithmetic` custom lint (Phase 8 §8.7) enforces this. R1 is
/// stated in four design documents and is the rule a well-meaning contributor
/// will break first, because summing two prices is the obvious thing to do.
final class Money implements Comparable<Money> {
  /// Creates an amount from integer paise.
  const Money(this.amountInPaise, {this.currency = Currency.inr});

  /// Zero in [currency].
  const Money.zero({this.currency = Currency.inr}) : amountInPaise = 0;

  /// Creates an amount from whole rupees. Convenience for fixtures and tests.
  const Money.rupees(int rupees, {this.currency = Currency.inr})
    : amountInPaise = rupees * 100;

  /// The amount, in the currency's minor unit.
  ///
  /// May be negative — a discount line is representable — so callers that
  /// require non-negativity must assert it themselves.
  final int amountInPaise;

  /// The currency this amount is denominated in.
  final Currency currency;

  /// Whole units, truncated. For display only; prefer the formatter.
  int get wholeUnits => amountInPaise ~/ 100;

  /// The sub-unit remainder, always in `0..99` for non-negative amounts.
  int get subUnits => amountInPaise.remainder(100).abs();

  /// Whether this amount has a non-zero sub-unit component.
  ///
  /// Indian prices are conventionally whole rupees, so the formatter omits
  /// decimals unless this is true.
  bool get hasSubUnits => subUnits != 0;

  bool get isZero => amountInPaise == 0;
  bool get isNegative => amountInPaise < 0;

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(amountInPaise + other.amountInPaise, currency: currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(amountInPaise - other.amountInPaise, currency: currency);
  }

  /// Scales by an integer quantity.
  ///
  /// Integer-only by design. A fractional multiplier would reintroduce the
  /// rounding ambiguity this class exists to eliminate, and percentage
  /// calculations (tax, fees, commission) are the server's business under R1.
  Money operator *(int quantity) =>
      Money(amountInPaise * quantity, currency: currency);

  Money operator -() => Money(-amountInPaise, currency: currency);

  bool operator <(Money other) => compareTo(other) < 0;
  bool operator <=(Money other) => compareTo(other) <= 0;
  bool operator >(Money other) => compareTo(other) > 0;
  bool operator >=(Money other) => compareTo(other) >= 0;

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return amountInPaise.compareTo(other.amountInPaise);
  }

  /// The discount of `this` against [original], as whole percent, truncated.
  ///
  /// Used to verify a server-supplied `discountPercent` in tests and fixtures,
  /// **not** to compute one for display (R1).
  int discountPercentAgainst(Money original) {
    _assertSameCurrency(original);
    if (original.amountInPaise <= 0) return 0;
    final saved = original.amountInPaise - amountInPaise;
    if (saved <= 0) return 0;
    return (saved * 100) ~/ original.amountInPaise;
  }

  void _assertSameCurrency(Money other) {
    assert(
      currency == other.currency,
      'Currency mismatch: ${currency.code} vs ${other.currency.code}. '
      'Mixing currencies silently is how a marketplace charges the wrong '
      'amount.',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.amountInPaise == amountInPaise &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(amountInPaise, currency);

  /// Diagnostic only — never shown to a user.
  @override
  String toString() => 'Money(${currency.code} $amountInPaise paise)';
}
