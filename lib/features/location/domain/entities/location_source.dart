/// How a [ResolvedLocation] was obtained — drives which empty/error copy
/// applies (§5a.4) and lets the offline banner distinguish a stale cache
/// from a fresh fix.
enum LocationSource { gps, search, pin, cached }
