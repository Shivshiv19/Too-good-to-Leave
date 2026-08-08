/// What a bag *contains*.
///
/// A guaranteed, contractual attribute of every listing (Phase 1 §3.1). In
/// India this is religious and ethical identity, not a taste preference: a
/// mystery bag that might contain egg is not a mild disappointment, it is a
/// violation and a churned user.
///
/// **Deliberately compiled in**, unlike the server-driven merchant taxonomy
/// (§2.3). Each value carries domain logic and legal weight, so it must not be
/// silently extensible by a server change.
enum DietaryEnvelope {
  /// No meat, no fish, no egg.
  pureVeg('pure_veg'),

  /// Vegetarian but contains egg.
  containsEgg('contains_egg'),

  /// Contains meat or fish.
  nonVeg('non_veg'),

  /// Jain — no root vegetables, no onion, no garlic. A strict *subset* of
  /// [pureVeg], which is why [DietaryPreference] models acceptance as a set.
  jain('jain');

  const DietaryEnvelope(this.wireValue);

  /// Value as it appears on the wire (Phase 7 §7.1.3).
  final String wireValue;

  /// Tolerant decoder (Phase 7 §7.1.4).
  ///
  /// Falls back to [nonVeg] — the **most restrictive** interpretation — on an
  /// unrecognised value. If we cannot understand what is in a bag, the safe
  /// failure is to treat it as something the fewest people will accept, so an
  /// unknown value is hidden from a vegetarian rather than offered to them.
  static DietaryEnvelope fromWire(String? value) =>
      DietaryEnvelope.values.firstWhere(
        (e) => e.wireValue == value,
        orElse: () => DietaryEnvelope.nonVeg,
      );
}

/// What a customer *will eat*, as one of four presets.
///
/// ## Amendment A7
///
/// Phase 2 originally modelled the customer's dietary field as a single
/// [DietaryEnvelope], mirroring the bag's. That was a category error.
///
/// A bag has **one** envelope — what it contains. A customer has an
/// **acceptance set** — what they will eat. Filtering is set membership, not
/// equality:
///
/// ```
/// visible(bag, customer) <=> bag.envelope ∈ customer.acceptedEnvelopes
/// ```
///
/// The concrete failure the single-enum model produced: Jain food contains no
/// onion or garlic and is a strict subset of pure vegetarian, so a
/// pure-vegetarian customer can eat a Jain bag. Under equality matching,
/// `preference == pureVeg` filters Jain bags *out* — hiding acceptable
/// inventory from a large segment, and doing so invisibly, because those bags
/// never appear in any result set anyone measures.
enum DietaryPreference {
  /// Accepts Jain only.
  jain('jain', {DietaryEnvelope.jain}),

  /// Accepts pure vegetarian — **including Jain**, which is a stricter subset.
  pureVeg('pure_veg', {DietaryEnvelope.pureVeg, DietaryEnvelope.jain}),

  /// Vegetarian who eats egg.
  vegWithEgg('veg_with_egg', {
    DietaryEnvelope.pureVeg,
    DietaryEnvelope.jain,
    DietaryEnvelope.containsEgg,
  }),

  /// Accepts everything.
  everything('everything', {
    DietaryEnvelope.pureVeg,
    DietaryEnvelope.jain,
    DietaryEnvelope.containsEgg,
    DietaryEnvelope.nonVeg,
  });

  const DietaryPreference(this.wireValue, this.acceptedEnvelopes);

  /// Preset key as sent on the wire and carried in the `?diet=` URL parameter
  /// (Phase 4 §4.5), which keeps deep links readable.
  final String wireValue;

  /// The set this preset expands to at query time (Phase 7 §7.4
  /// `acceptedEnvelopes`).
  final Set<DietaryEnvelope> acceptedEnvelopes;

  /// Whether a bag with [envelope] is acceptable under this preference.
  bool accepts(DietaryEnvelope envelope) =>
      acceptedEnvelopes.contains(envelope);

  /// Whether this preference is narrower than [other].
  ///
  /// Drives the §5b.4 filter-sheet note: widening away from the user's stored
  /// preference shows a calm one-line warning and applies for the session only
  /// (D-b5). Accidentally and permanently widening a religious constraint is a
  /// harm we can cheaply prevent.
  bool isNarrowerThan(DietaryPreference other) =>
      acceptedEnvelopes.length < other.acceptedEnvelopes.length &&
      other.acceptedEnvelopes.containsAll(acceptedEnvelopes);

  /// Tolerant decoder. Falls back to [pureVeg] rather than [everything].
  ///
  /// The conservative default matters: showing a vegetarian user non-vegetarian
  /// food because a preference failed to parse is a harm, whereas showing an
  /// omnivore too little food is an inconvenience they can correct in one tap.
  static DietaryPreference fromWire(String? value) =>
      DietaryPreference.values.firstWhere(
        (p) => p.wireValue == value,
        orElse: () => DietaryPreference.pureVeg,
      );
}
