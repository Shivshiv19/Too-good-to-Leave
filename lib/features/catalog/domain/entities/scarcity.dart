/// Amendment A8 — the list/map/search feed's cached scarcity signal.
///
/// **Deliberately not a count.** `GET /v1/bags` (Phase 7 §7.4) cannot return
/// an exact `quantityAvailable`, so a cached card is structurally incapable
/// of asserting "3 left" and being wrong — the rule is enforced by the
/// schema, not by every call site remembering it.
enum Scarcity {
  few,
  none;

  /// Unknown wire values fall back to [none] — the conservative direction:
  /// omitting a scarcity cue that should have shown is a missed nudge,
  /// asserting one that shouldn't have is a lie the user can catch.
  static Scarcity fromWire(String value) => switch (value) {
    'few' => Scarcity.few,
    _ => Scarcity.none,
  };
}
