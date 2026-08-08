import 'package:flutter_test/flutter_test.dart';
import 'package:surplus_marketplace/core/domain/dietary_envelope.dart';

void main() {
  group('DietaryPreference acceptance sets (amendment A7)', () {
    test('a pure-vegetarian customer accepts Jain bags', () {
      // The regression this whole amendment exists to prevent.
      //
      // Jain food contains no onion or garlic and is a strict SUBSET of pure
      // vegetarian, so a pure-vegetarian customer can eat a Jain bag. Under the
      // original single-enum model, `preference == pureVeg` matched by equality
      // and filtered Jain bags out — hiding acceptable inventory from a large
      // segment, and hiding it INVISIBLY, because those bags never appeared in
      // any result set anyone measures.
      expect(
        DietaryPreference.pureVeg.accepts(DietaryEnvelope.jain),
        isTrue,
        reason: 'Jain is a subset of pure vegetarian',
      );
    });

    test('a Jain customer accepts only Jain bags', () {
      expect(DietaryPreference.jain.accepts(DietaryEnvelope.jain), isTrue);
      expect(DietaryPreference.jain.accepts(DietaryEnvelope.pureVeg), isFalse);
      expect(
        DietaryPreference.jain.accepts(DietaryEnvelope.containsEgg),
        isFalse,
      );
      expect(DietaryPreference.jain.accepts(DietaryEnvelope.nonVeg), isFalse);
    });

    test('pure vegetarian rejects egg and meat', () {
      expect(
        DietaryPreference.pureVeg.accepts(DietaryEnvelope.containsEgg),
        isFalse,
      );
      expect(
        DietaryPreference.pureVeg.accepts(DietaryEnvelope.nonVeg),
        isFalse,
      );
    });

    test('veg-with-egg accepts three envelopes but not meat', () {
      const p = DietaryPreference.vegWithEgg;
      expect(p.accepts(DietaryEnvelope.pureVeg), isTrue);
      expect(p.accepts(DietaryEnvelope.jain), isTrue);
      expect(p.accepts(DietaryEnvelope.containsEgg), isTrue);
      expect(p.accepts(DietaryEnvelope.nonVeg), isFalse);
    });

    test('everything accepts all envelopes', () {
      for (final envelope in DietaryEnvelope.values) {
        expect(DietaryPreference.everything.accepts(envelope), isTrue);
      }
    });

    test('acceptance sets form a strict chain of widening restrictiveness', () {
      // Jain ⊂ pureVeg ⊂ vegWithEgg ⊂ everything.
      expect(
        DietaryPreference.jain.isNarrowerThan(DietaryPreference.pureVeg),
        isTrue,
      );
      expect(
        DietaryPreference.pureVeg.isNarrowerThan(DietaryPreference.vegWithEgg),
        isTrue,
      );
      expect(
        DietaryPreference.vegWithEgg.isNarrowerThan(
          DietaryPreference.everything,
        ),
        isTrue,
      );
      expect(
        DietaryPreference.everything.isNarrowerThan(DietaryPreference.jain),
        isFalse,
      );
    });
  });

  group('tolerant decoding (Phase 7 §7.1.4)', () {
    test('an unknown envelope falls back to the most restrictive value', () {
      // If we cannot tell what is in a bag, the safe failure is to treat it as
      // something the fewest people accept — so it is hidden from a vegetarian
      // rather than offered to them.
      expect(DietaryEnvelope.fromWire('gluten_free'), DietaryEnvelope.nonVeg);
      expect(DietaryEnvelope.fromWire(null), DietaryEnvelope.nonVeg);
    });

    test('an unknown preference falls back to pure vegetarian', () {
      // Conservative in the other direction: showing a vegetarian non-veg food
      // because a preference failed to parse is a harm; showing an omnivore too
      // little food is an inconvenience they fix in one tap.
      expect(DietaryPreference.fromWire('vegan'), DietaryPreference.pureVeg);
      expect(DietaryPreference.fromWire(null), DietaryPreference.pureVeg);
    });

    test('known wire values round-trip', () {
      for (final e in DietaryEnvelope.values) {
        expect(DietaryEnvelope.fromWire(e.wireValue), e);
      }
      for (final p in DietaryPreference.values) {
        expect(DietaryPreference.fromWire(p.wireValue), p);
      }
    });
  });
}
