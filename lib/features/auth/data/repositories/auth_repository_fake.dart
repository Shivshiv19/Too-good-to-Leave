import 'dart:math';

import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/core/storage/prefs.dart';
import 'package:surplus_marketplace/core/storage/secure_store.dart';
import 'package:surplus_marketplace/features/auth/domain/entities/auth_tokens.dart';
import 'package:surplus_marketplace/features/auth/domain/entities/customer.dart';
import 'package:surplus_marketplace/features/auth/domain/entities/otp_channel.dart';
import 'package:surplus_marketplace/features/auth/domain/entities/otp_request.dart';
import 'package:surplus_marketplace/features/auth/domain/repositories/auth_repository.dart';

class _PendingOtp {
  _PendingOtp({required this.phoneE164, required this.issuedAt});

  final String phoneE164;
  final DateTime issuedAt;
  int attemptsRemaining = 3;
}

/// Stands in for the server in the `dev` flavour (Phase 1 locked decision).
///
/// **The code is always `123456`.** There is no SMS provider in `dev`, so a
/// fixed dev-only code is what "fake" means here — the same convention as
/// [ConfigRepositoryFake] standing in for a config server. Never read from
/// an environment where a real code could be confused with this one.
///
/// **Scope note (Phase 9 Step 3b).** §7.2.4's device-token *merge* has
/// nothing to merge yet — no anonymous cart, saved location, or notify-me
/// state exists (those land with `catalog`/`location`, Phase 8 §8.12 steps
/// 4–5). This fake still generates and persists a local device ID (the A23
/// half that *is* meaningful today), so the seam is ready when there is
/// something to attribute. Real rotation (A24) is deferred to the
/// `core/network` interceptor — see `AuthTokens`'s class doc.
final class AuthRepositoryFake implements AuthRepository {
  AuthRepositoryFake({
    required Prefs prefs,
    required SecureStore secureStore,
    required Clock clock,
  }) : _prefs = prefs,
       _secureStore = secureStore,
       _clock = clock;

  final Prefs _prefs;
  final SecureStore _secureStore;
  final Clock _clock;

  final _pending = <String, _PendingOtp>{};
  final _random = Random.secure();

  /// Set by [signInWithGoogle], consumed by the next [verifyOtp] — stands
  /// in for the real binding's "already has a non-anonymous session"
  /// check, since there's no real OAuth redirect to come back from here.
  bool _pendingGoogleHandoff = false;

  static const _devCode = '123456';
  static const _otpValidity = Duration(minutes: 10);
  static const _lockoutDuration = Duration(minutes: 15);

  static const _accessTokenKey = 'auth.accessToken';
  static const _refreshTokenKey = 'auth.refreshToken';
  static const _expiresAtKey = 'auth.expiresAt';

  /// The phone of whichever account the current session belongs to.
  /// Cleared on [logout] — unlike the `_customer*` record below, this is
  /// session state, not account state.
  static const _sessionPhoneKey = 'auth.session.phone';

  // Account records are keyed by phone number, not "the current customer" —
  // logging out must end the session without deleting the account, so a
  // returning phone number gets its existing id and name back rather than a
  // fresh identity. This is what the "same phone number gets the same
  // customer id on re-auth" test asserts.
  String _customerIdKey(String phone) => 'auth.customers.$phone.id';
  String _customerNameKey(String phone) => 'auth.customers.$phone.name';
  String _customerEmailKey(String phone) => 'auth.customers.$phone.email';
  String _customerAvatarKey(String phone) => 'auth.customers.$phone.avatar';

  @override
  Future<OtpRequest> requestOtp({
    required String phoneE164,
    OtpChannel channel = OtpChannel.sms,
  }) async {
    final requestId = 'req_${_randomHex(12)}';
    _pending[requestId] = _PendingOtp(
      phoneE164: phoneE164,
      issuedAt: _clock.now(),
    );
    return OtpRequest(
      requestId: requestId,
      expiresIn: _otpValidity,
      resendAfter: const Duration(seconds: 30),
      channelsAvailable: const {
        OtpChannel.sms,
        OtpChannel.whatsapp,
        OtpChannel.voice,
      },
    );
  }

  @override
  Future<Customer> verifyOtp({
    required String requestId,
    required String code,
  }) async {
    final pending = _pending[requestId];
    if (pending == null) {
      // Consumed or never existed — the safe reading is "expired", not a
      // silent wrong-code rejection that gives no path forward.
      throw const OtpExpiredException();
    }
    if (_clock.now().isAfter(pending.issuedAt.add(_otpValidity))) {
      _pending.remove(requestId);
      throw const OtpExpiredException();
    }
    if (code != _devCode) {
      pending.attemptsRemaining--;
      if (pending.attemptsRemaining <= 0) {
        _pending.remove(requestId);
        throw const OtpAttemptsExhaustedException(retryAfter: _lockoutDuration);
      }
      throw OtpInvalidException(attemptsRemaining: pending.attemptsRemaining);
    }

    _pending.remove(requestId);
    final fromGoogle = _pendingGoogleHandoff;
    _pendingGoogleHandoff = false;
    final customer = await _findOrCreateCustomer(
      pending.phoneE164,
      fromGoogle: fromGoogle,
    );
    await _persistSession(customer);
    return customer;
  }

  @override
  Future<void> signInWithGoogle() async {
    // No real redirect exists in this fake — the button just flags the
    // handoff, then the ordinary phone-entry/OTP screens collect a phone
    // number exactly as they would after a real Google round-trip, letting
    // `dev` exercise the whole flow (name/email pre-filled, profile-setup
    // skipped) with no real Google credentials.
    _pendingGoogleHandoff = true;
  }

  @override
  Future<bool> hasPendingGoogleSignIn() async => _pendingGoogleHandoff;

  @override
  Future<Customer> updateProfile({required String name}) async {
    final phone = _requireSessionPhone();
    final id = _prefs.getString(_customerIdKey(phone))!;
    await _prefs.setString(_customerNameKey(phone), name);
    return _customerFor(id, phone);
  }

  @override
  Future<Customer> updateAccountDetails({
    String? name,
    String? email,
    String? avatarUrl,
    bool clearAvatar = false,
  }) async {
    final phone = _requireSessionPhone();
    final id = _prefs.getString(_customerIdKey(phone))!;
    if (name != null) await _prefs.setString(_customerNameKey(phone), name);
    if (email != null) await _prefs.setString(_customerEmailKey(phone), email);
    if (clearAvatar) {
      await _prefs.remove(_customerAvatarKey(phone));
    } else if (avatarUrl != null) {
      await _prefs.setString(_customerAvatarKey(phone), avatarUrl);
    }
    return _customerFor(id, phone);
  }

  @override
  Future<OtpRequest> requestReverificationOtp() =>
      requestOtp(phoneE164: _requireSessionPhone());

  @override
  Future<void> verifyReverificationOtp({
    required String requestId,
    required String code,
  }) async {
    // Reuses `verifyOtp`'s exact validation — same code, expiry, and
    // attempt-lockout rules — but discards the `Customer` it returns and
    // deliberately does **not** call `_persistSession`: re-verification
    // proves possession, it never mutates or extends the existing session.
    await verifyOtp(requestId: requestId, code: code);
  }

  @override
  Future<Customer?> restoreSession() async {
    try {
      final accessToken = await _secureStore.read(_accessTokenKey);
      if (accessToken == null) return null;
      final phone = _prefs.getString(_sessionPhoneKey);
      if (phone == null) return null;
      final id = _prefs.getString(_customerIdKey(phone));
      if (id == null) return null;
      return _customerFor(id, phone);
    } on Object {
      // §5a.1 — an unreadable local session is signed-out, never a crash.
      return null;
    }
  }

  @override
  Future<void> logout() async {
    // Ends the session only. The account record under `_customerIdKey`/
    // `_customerNameKey` (keyed by phone, not by session) is untouched, so
    // signing back in with the same number returns the same identity.
    await _secureStore.delete(_accessTokenKey);
    await _secureStore.delete(_refreshTokenKey);
    await _secureStore.delete(_expiresAtKey);
    await _prefs.remove(_sessionPhoneKey);
  }

  Future<Customer> _findOrCreateCustomer(
    String phoneE164, {
    bool fromGoogle = false,
  }) async {
    final existingId = _prefs.getString(_customerIdKey(phoneE164));
    if (existingId != null) return _customerFor(existingId, phoneE164);
    final id = 'cust_${_randomHex(12)}';
    await _prefs.setString(_customerIdKey(phoneE164), id);
    // Stands in for Google already having told us who they are — a real
    // Google sign-in never needs the separate "what's your name" screen,
    // and this fake should exercise that same skip.
    if (fromGoogle) {
      await _prefs.setString(_customerNameKey(phoneE164), 'Test Google User');
      await _prefs.setString(
        _customerEmailKey(phoneE164),
        'testgoogleuser@example.com',
      );
    }
    return _customerFor(id, phoneE164);
  }

  Customer _customerFor(String id, String phone) => Customer(
    id: id,
    phoneE164: phone,
    name: _prefs.getString(_customerNameKey(phone)),
    email: _prefs.getString(_customerEmailKey(phone)),
    avatarUrl: _prefs.getString(_customerAvatarKey(phone)),
  );

  String _requireSessionPhone() {
    final phone = _prefs.getString(_sessionPhoneKey);
    if (phone == null) {
      // Only reachable by a programming error — every caller of this is
      // only ever shown once §4.3 confirms isAuthenticated.
      throw StateError('No signed-in customer for this session.');
    }
    return phone;
  }

  Future<void> _persistSession(Customer customer) async {
    final tokens = AuthTokens(
      accessToken: 'fake_access_${_randomHex(16)}',
      refreshToken: 'fake_refresh_${_randomHex(16)}',
      expiresAt: _clock.now().add(const Duration(minutes: 15)),
    );
    await _secureStore.write(_accessTokenKey, tokens.accessToken);
    await _secureStore.write(_refreshTokenKey, tokens.refreshToken);
    await _secureStore.write(_expiresAtKey, tokens.expiresAt.toIso8601String());
    await _prefs.setString(_sessionPhoneKey, customer.phoneE164);
  }

  String _randomHex(int length) => List.generate(
    length,
    (_) => _random.nextInt(16).toRadixString(16),
  ).join();
}
