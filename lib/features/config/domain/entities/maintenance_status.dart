/// Planned-outage state from `GET /v1/config` (Phase 7 §7.3).
///
/// Distinct from [MaintenanceException] (`core/error/app_exception.dart`),
/// which is thrown when a mid-session request is rejected because the server
/// entered maintenance *after* Splash last checked. This type is the plain
/// data read at bootstrap; the exception is the same fact arriving through a
/// different door.
final class MaintenanceStatus {
  const MaintenanceStatus({required this.active, this.etaAt});

  /// Whether the platform is currently in maintenance.
  final bool active;

  /// Expected return time, if known.
  ///
  /// Null when unknown — §5a.10 renders that as an open-ended wait rather
  /// than implying an ETA the platform cannot back up. An unspecified outage
  /// reads as abandonment, so the UI says so rather than guessing.
  final DateTime? etaAt;
}
