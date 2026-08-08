import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:surplus_marketplace/core/domain/lat_lng.dart';

part 'coverage_status.freezed.dart';

/// `GET /v1/coverage` (Phase 7 §7.4) — the signal that lets the client tell
/// A10's three zero-result states apart. An empty bag list is identical on
/// the wire whether there is no coverage, no supply right now, or the
/// user's own facets excluded everything; only the server can distinguish
/// the first two, so this is a dedicated endpoint rather than something
/// inferred from `GET /v1/bags` returning zero items.
///
/// A sealed union with per-variant data — `freezed` per D-1, not
/// hand-written, since there are no constructor invariants to enforce here.
@freezed
sealed class CoverageStatus with _$CoverageStatus {
  const factory CoverageStatus.live() = CoverageLive;

  const factory CoverageStatus.noSupplyNow({
    required String typicalWindowStart,
    required int merchantCountInArea,
  }) = CoverageNoSupplyNow;

  const factory CoverageStatus.noCoverage({
    required String nearestLiveAreaName,
    required int nearestLiveAreaDistanceMetres,
    required LatLng nearestLiveAreaAnchor,
  }) = CoverageNoCoverage;
}
