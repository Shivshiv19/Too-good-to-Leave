import 'package:flutter_test/flutter_test.dart';
import 'package:surplus_marketplace/app/session/session_state.dart';

void main() {
  group('SessionState', () {
    test('starts unbootstrapped with every flag at its safe default', () {
      final session = SessionState();
      expect(session.isBootstrapped, isFalse);
      expect(session.forceUpdateRequired, isFalse);
      expect(session.maintenanceMode, isFalse);
      expect(session.hasSeenOnboarding, isFalse);
      expect(session.hasLocation, isFalse);
    });

    test('markBootstrapped sets every flag it is given and notifies', () {
      final session = SessionState();
      var notified = 0;
      session.addListener(() => notified++);

      final eta = DateTime(2026, 8, 1);
      session.markBootstrapped(
        forceUpdateRequired: true,
        maintenanceMode: true,
        hasSeenOnboarding: true,
        isAuthenticated: true,
        isProfileComplete: true,
        hasLocation: true,
        maintenanceEtaAt: eta,
      );

      expect(session.isBootstrapped, isTrue);
      expect(session.forceUpdateRequired, isTrue);
      expect(session.maintenanceMode, isTrue);
      expect(session.hasSeenOnboarding, isTrue);
      expect(session.isAuthenticated, isTrue);
      expect(session.isProfileComplete, isTrue);
      expect(session.hasLocation, isTrue);
      expect(session.maintenanceEtaAt, eta);
      expect(notified, 1);
    });

    test('markOnboardingSeen flips only that flag and notifies', () {
      final session = SessionState()
        ..markBootstrapped(
          forceUpdateRequired: false,
          maintenanceMode: false,
          hasSeenOnboarding: false,
          isAuthenticated: false,
          isProfileComplete: false,
          hasLocation: false,
        );
      var notified = 0;
      session.addListener(() => notified++);

      session.markOnboardingSeen();

      expect(session.hasSeenOnboarding, isTrue);
      expect(session.isBootstrapped, isTrue);
      expect(notified, 1);
    });

    test('markLocationResolved flips only that flag and notifies', () {
      final session = SessionState();
      var notified = 0;
      session.addListener(() => notified++);

      session.markLocationResolved();

      expect(session.hasLocation, isTrue);
      expect(notified, 1);
    });

    test('markAuthenticated sets both auth flags and notifies', () {
      final session = SessionState();
      var notified = 0;
      session.addListener(() => notified++);

      session.markAuthenticated(isProfileComplete: false);

      expect(session.isAuthenticated, isTrue);
      expect(session.isProfileComplete, isFalse);
      expect(notified, 1);
    });

    test('markProfileComplete flips only that flag', () {
      final session = SessionState()
        ..markAuthenticated(isProfileComplete: false);

      session.markProfileComplete();

      expect(session.isProfileComplete, isTrue);
      expect(session.isAuthenticated, isTrue);
    });

    test('markSignedOut clears both auth flags', () {
      final session = SessionState()
        ..markAuthenticated(isProfileComplete: true);

      session.markSignedOut();

      expect(session.isAuthenticated, isFalse);
      expect(session.isProfileComplete, isFalse);
    });

    test('markBootstrapped accepts an unresolvedPaymentOrderId (A3)', () {
      final session = SessionState()
        ..markBootstrapped(
          forceUpdateRequired: false,
          maintenanceMode: false,
          hasSeenOnboarding: true,
          isAuthenticated: true,
          isProfileComplete: true,
          hasLocation: true,
          unresolvedPaymentOrderId: 'ord_123',
        );

      expect(session.unresolvedPaymentOrderId, 'ord_123');
    });

    test('clearUnresolvedPayment resets the flag and notifies', () {
      final session = SessionState()
        ..markBootstrapped(
          forceUpdateRequired: false,
          maintenanceMode: false,
          hasSeenOnboarding: true,
          isAuthenticated: true,
          isProfileComplete: true,
          hasLocation: true,
          unresolvedPaymentOrderId: 'ord_123',
        );
      var notified = 0;
      session.addListener(() => notified++);

      session.clearUnresolvedPayment();

      expect(session.unresolvedPaymentOrderId, isNull);
      expect(notified, 1);
    });
  });
}
