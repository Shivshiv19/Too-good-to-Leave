import 'package:flutter_test/flutter_test.dart';
import 'package:surplus_marketplace/core/domain/grievance_officer.dart';
import 'package:surplus_marketplace/features/config/domain/entities/maintenance_status.dart';
import 'package:surplus_marketplace/features/config/domain/entities/policy_values.dart';
import 'package:surplus_marketplace/features/config/domain/entities/remote_config.dart';

RemoteConfig _configWithMinVersion(String minVersion) => RemoteConfig(
  minSupportedAppVersion: minVersion,
  maintenance: const MaintenanceStatus(active: false),
  featureFlags: const {},
  policyValues: const PolicyValues(
    cancellationCutoffBeforeWindow: Duration(minutes: 60),
    noShowRefundPolicy: 'none',
    refundSlaWorkingDays: (min: 3, max: 7),
    grievanceSla: Duration(hours: 48),
    purchaseCapPerListing: 2,
    holdTtl: Duration(seconds: 540),
    grievanceOfficer: GrievanceOfficer(
      name: 'Priya Sharma',
      designation: 'Grievance Officer',
      email: 'grievance@example.com',
      phone: '+91 80 4567 8900',
      address: 'Bengaluru, Karnataka',
    ),
  ),
  taxonomyEtag: 'tx_1',
);

void main() {
  group('RemoteConfig.requiresForceUpdateFor (§4.3 rule 1)', () {
    test('is false when the client is at the minimum version', () {
      expect(
        _configWithMinVersion('1.2.0').requiresForceUpdateFor('1.2.0'),
        isFalse,
      );
    });

    test('is false when the client is above the minimum version', () {
      expect(
        _configWithMinVersion('1.2.0').requiresForceUpdateFor('1.3.0'),
        isFalse,
      );
      expect(
        _configWithMinVersion('1.2.0').requiresForceUpdateFor('2.0.0'),
        isFalse,
      );
    });

    test('is true when the client is below the minimum version', () {
      expect(
        _configWithMinVersion('1.2.0').requiresForceUpdateFor('1.1.9'),
        isTrue,
      );
      expect(
        _configWithMinVersion('2.0.0').requiresForceUpdateFor('1.9.9'),
        isTrue,
      );
    });

    test('compares numerically, not lexically', () {
      // A naive string comparison would place "1.9.0" above "1.10.0".
      expect(
        _configWithMinVersion('1.10.0').requiresForceUpdateFor('1.9.0'),
        isTrue,
      );
      expect(
        _configWithMinVersion('1.9.0').requiresForceUpdateFor('1.10.0'),
        isFalse,
      );
    });

    test('handles unequal segment counts', () {
      expect(
        _configWithMinVersion('1.2.0').requiresForceUpdateFor('1.2'),
        isFalse,
      );
      expect(
        _configWithMinVersion('1.2.1').requiresForceUpdateFor('1.2'),
        isTrue,
      );
    });
  });
}
