import 'package:surplus_marketplace/features/config/domain/entities/maintenance_status.dart';
import 'package:surplus_marketplace/features/config/domain/entities/policy_values.dart';

/// The `GET /v1/config` response (Phase 7 §7.3), fetched once at Splash.
///
/// `featureFlags` is deliberately untyped (`Map<String, bool>`): flags are
/// added and retired server-side between releases, and a client that must be
/// redeployed to recognise a new flag key defeats the point of a flag.
final class RemoteConfig {
  const RemoteConfig({
    required this.minSupportedAppVersion,
    required this.maintenance,
    required this.featureFlags,
    required this.policyValues,
    required this.taxonomyEtag,
  });

  /// Lowest client version still permitted to transact, as a dotted version
  /// string (e.g. `"1.0.0"`).
  final String minSupportedAppVersion;

  final MaintenanceStatus maintenance;

  final Map<String, bool> featureFlags;

  final PolicyValues policyValues;

  /// Current server-side taxonomy revision. Compared against the locally
  /// cached ETag to decide whether `GET /v1/config/taxonomy` is worth a
  /// round trip (§7.3).
  final String taxonomyEtag;

  /// Whether [currentVersion] is below [minSupportedAppVersion].
  ///
  /// Outranks every other guard (§4.3 rule 1) — a client this old is not
  /// merely stale, it has been declared unsafe to transact on. Exposed here,
  /// next to the value it compares against, rather than in the router, so
  /// the rule has exactly one home.
  bool requiresForceUpdateFor(String currentVersion) =>
      _compareVersions(currentVersion, minSupportedAppVersion) < 0;

  static int _compareVersions(String a, String b) {
    final partsA = a.split('.').map(int.parse).toList();
    final partsB = b.split('.').map(int.parse).toList();
    final length = partsA.length > partsB.length
        ? partsA.length
        : partsB.length;
    for (var i = 0; i < length; i++) {
      final valueA = i < partsA.length ? partsA[i] : 0;
      final valueB = i < partsB.length ? partsB[i] : 0;
      if (valueA != valueB) return valueA.compareTo(valueB);
    }
    return 0;
  }
}
