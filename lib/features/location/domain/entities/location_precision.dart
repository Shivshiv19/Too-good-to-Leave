/// How confidently [ResolvedLocation] pins the customer, distinct from *how*
/// it was obtained ([LocationSource]) — §5a.4's validation rule requires the
/// UI to show only what precision actually earned: reverse-geocoding a
/// coarse fix into a confident street address is a lie the user will act on.
enum LocationPrecision { precise, approximate }
