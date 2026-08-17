import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/core/storage/prefs.dart';
import 'package:surplus_marketplace/core/storage/secure_store.dart';
import 'package:surplus_marketplace/features/auth/data/repositories/auth_repository_fake.dart';

/// In-memory stand-in for the platform channel `flutter_secure_storage`
/// normally talks to — there is no real Keystore/Keychain in a unit test.
/// Swapping [FlutterSecureStoragePlatform.instance] is the package's own
/// documented test seam (`flutter_secure_storage_platform_interface`).
class _FakeSecureStoragePlatform extends FlutterSecureStoragePlatform {
  final _store = <String, String>{};

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async => _store[key] = value;

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => _store[key];

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => _store.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => _store.remove(key);

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => Map.of(_store);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      _store.clear();
}

Future<AuthRepositoryFake> _repository({
  Clock clock = const SystemClock(),
}) async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStoragePlatform.instance = _FakeSecureStoragePlatform();
  return AuthRepositoryFake(
    prefs: await Prefs.open(),
    secureStore: const SecureStore(FlutterSecureStorage()),
    clock: clock,
  );
}

void main() {
  const phone = '+919812345678';

  group('AuthRepositoryFake — OTP flow', () {
    test('the dev code (123456) verifies successfully', () async {
      final repo = await _repository();
      final request = await repo.requestOtp(phoneE164: phone);
      final customer = await repo.verifyOtp(
        requestId: request.requestId,
        code: '123456',
      );
      expect(customer.phoneE164, phone);
      expect(customer.isProfileComplete, isFalse);
    });

    test(
      'a wrong code decrements attempts and throws OtpInvalidException',
      () async {
        final repo = await _repository();
        final request = await repo.requestOtp(phoneE164: phone);
        await expectLater(
          repo.verifyOtp(requestId: request.requestId, code: '000000'),
          throwsA(
            isA<OtpInvalidException>().having(
              (e) => e.attemptsRemaining,
              'attemptsRemaining',
              2,
            ),
          ),
        );
      },
    );

    test(
      'exhausting all attempts throws OtpAttemptsExhaustedException',
      () async {
        final repo = await _repository();
        final request = await repo.requestOtp(phoneE164: phone);
        for (var i = 0; i < 2; i++) {
          await expectLater(
            repo.verifyOtp(requestId: request.requestId, code: '000000'),
            throwsA(isA<OtpInvalidException>()),
          );
        }
        await expectLater(
          repo.verifyOtp(requestId: request.requestId, code: '000000'),
          throwsA(isA<OtpAttemptsExhaustedException>()),
        );
      },
    );

    test('a code older than 10 minutes throws OtpExpiredException', () async {
      final clock = FixedClock(DateTime(2026, 1, 1, 12));
      final repo = await _repository(clock: clock);
      final request = await repo.requestOtp(phoneE164: phone);
      clock.advance(const Duration(minutes: 11));
      await expectLater(
        repo.verifyOtp(requestId: request.requestId, code: '123456'),
        throwsA(isA<OtpExpiredException>()),
      );
    });

    test(
      'an unknown requestId throws OtpExpiredException, not a crash',
      () async {
        final repo = await _repository();
        await expectLater(
          repo.verifyOtp(requestId: 'req_never_issued', code: '123456'),
          throwsA(isA<OtpExpiredException>()),
        );
      },
    );

    test('a consumed requestId cannot be replayed', () async {
      final repo = await _repository();
      final request = await repo.requestOtp(phoneE164: phone);
      await repo.verifyOtp(requestId: request.requestId, code: '123456');
      await expectLater(
        repo.verifyOtp(requestId: request.requestId, code: '123456'),
        throwsA(isA<OtpExpiredException>()),
      );
    });

    test(
      'the same phone number gets the same customer id on re-auth',
      () async {
        final repo = await _repository();
        final first = await repo.verifyOtp(
          requestId: (await repo.requestOtp(phoneE164: phone)).requestId,
          code: '123456',
        );
        await repo.logout();
        final second = await repo.verifyOtp(
          requestId: (await repo.requestOtp(phoneE164: phone)).requestId,
          code: '123456',
        );
        expect(second.id, first.id);
      },
    );
  });

  group('AuthRepositoryFake — profile and session', () {
    test(
      'updateProfile sets the name and isProfileComplete flips true',
      () async {
        final repo = await _repository();
        await repo.verifyOtp(
          requestId: (await repo.requestOtp(phoneE164: phone)).requestId,
          code: '123456',
        );
        final updated = await repo.updateProfile(name: 'Asha');
        expect(updated.name, 'Asha');
        expect(updated.isProfileComplete, isTrue);
      },
    );

    test('restoreSession returns null when signed out', () async {
      final repo = await _repository();
      expect(await repo.restoreSession(), isNull);
    });

    test('restoreSession returns the customer after verifyOtp', () async {
      final repo = await _repository();
      final verified = await repo.verifyOtp(
        requestId: (await repo.requestOtp(phoneE164: phone)).requestId,
        code: '123456',
      );
      final restored = await repo.restoreSession();
      expect(restored, isNotNull);
      expect(restored!.id, verified.id);
      expect(restored.phoneE164, phone);
    });

    test(
      'logout clears the session so restoreSession returns null again',
      () async {
        final repo = await _repository();
        await repo.verifyOtp(
          requestId: (await repo.requestOtp(phoneE164: phone)).requestId,
          code: '123456',
        );
        await repo.logout();
        expect(await repo.restoreSession(), isNull);
      },
    );
  });

  group('AuthRepositoryFake — updateAccountDetails (§5f.2)', () {
    Future<AuthRepositoryFake> signedIn() async {
      final repo = await _repository();
      await repo.verifyOtp(
        requestId: (await repo.requestOtp(phoneE164: phone)).requestId,
        code: '123456',
      );
      return repo;
    }

    test('sets name, email, and avatarUrl together', () async {
      final repo = await signedIn();
      final updated = await repo.updateAccountDetails(
        name: 'Asha',
        email: 'asha@example.com',
        avatarUrl: 'data:image/jpeg;base64,AAAA',
      );
      expect(updated.name, 'Asha');
      expect(updated.email, 'asha@example.com');
      expect(updated.avatarUrl, 'data:image/jpeg;base64,AAAA');
    });

    test('clearAvatar removes a previously-set avatar', () async {
      final repo = await signedIn();
      await repo.updateAccountDetails(avatarUrl: 'data:image/jpeg;base64,AAAA');
      final cleared = await repo.updateAccountDetails(clearAvatar: true);
      expect(cleared.avatarUrl, isNull);
    });

    test('phoneE164 is never a parameter — it never changes', () async {
      final repo = await signedIn();
      final updated = await repo.updateAccountDetails(name: 'Asha');
      expect(updated.phoneE164, phone);
    });
  });

  group('AuthRepositoryFake — signInWithGoogle', () {
    test(
      'a phone verified right after signInWithGoogle arrives with a name '
      'and email already filled in, and counts as profile-complete',
      () async {
        final repo = await _repository();
        await repo.signInWithGoogle();
        final customer = await repo.verifyOtp(
          requestId: (await repo.requestOtp(phoneE164: phone)).requestId,
          code: '123456',
        );
        expect(customer.phoneE164, phone);
        expect(customer.name, isNotEmpty);
        expect(customer.email, isNotEmpty);
        expect(customer.isProfileComplete, isTrue);
      },
    );

    test(
      'a phone verified with no prior signInWithGoogle call behaves exactly '
      "like today's phone-only signup — no name, not profile-complete",
      () async {
        final repo = await _repository();
        final customer = await repo.verifyOtp(
          requestId: (await repo.requestOtp(phoneE164: phone)).requestId,
          code: '123456',
        );
        expect(customer.name, isNull);
        expect(customer.isProfileComplete, isFalse);
      },
    );

    test(
      'the Google handoff only applies to the very next verifyOtp, not '
      'ones after it',
      () async {
        final repo = await _repository();
        await repo.signInWithGoogle();
        await repo.verifyOtp(
          requestId: (await repo.requestOtp(phoneE164: phone)).requestId,
          code: '123456',
        );
        const secondPhone = '+919812345679';
        final second = await repo.verifyOtp(
          requestId: (await repo.requestOtp(
            phoneE164: secondPhone,
          )).requestId,
          code: '123456',
        );
        expect(second.name, isNull);
      },
    );
  });

  group(
    'AuthRepositoryFake — requestReverificationOtp/verifyReverificationOtp (§5f.11)',
    () {
      test('the dev code verifies without mutating the session', () async {
        final repo = await _repository();
        final original = await repo.verifyOtp(
          requestId: (await repo.requestOtp(phoneE164: phone)).requestId,
          code: '123456',
        );
        final reverify = await repo.requestReverificationOtp();
        await repo.verifyReverificationOtp(
          requestId: reverify.requestId,
          code: '123456',
        );
        final stillSignedIn = await repo.restoreSession();
        expect(stillSignedIn!.id, original.id);
      });

      test('a wrong code throws OtpInvalidException', () async {
        final repo = await _repository();
        await repo.verifyOtp(
          requestId: (await repo.requestOtp(phoneE164: phone)).requestId,
          code: '123456',
        );
        final reverify = await repo.requestReverificationOtp();
        await expectLater(
          repo.verifyReverificationOtp(
            requestId: reverify.requestId,
            code: '000000',
          ),
          throwsA(isA<OtpInvalidException>()),
        );
      });
    },
  );
}
