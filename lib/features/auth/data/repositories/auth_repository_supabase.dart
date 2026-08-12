import 'package:supabase_flutter/supabase_flutter.dart' hide OtpChannel;
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/features/auth/auth.dart';

/// Fixed 6-digit code accepted for every OTP verification — the app's own
/// scoping decision (real Supabase Auth session + real data everywhere
/// else, but no real SMS/email provider): "we can use hardcoded OTP".
/// Never generated, never sent anywhere; [AuthRepositorySupabase.requestOtp]
/// doesn't dispatch an SMS at all.
const _fixedOtpCode = '123456';

Customer _customerFromRow(Map<String, dynamic> row) => Customer(
  id: row['id'] as String,
  phoneE164: row['phone_e164'] as String,
  name: row['name'] as String?,
  email: row['email'] as String?,
  avatarUrl: row['avatar_url'] as String?,
);

/// Real Supabase Auth sessions behind a hardcoded-OTP front door.
///
/// [requestOtp]/[verifyOtp] never talk to an SMS provider — the code is
/// always [_fixedOtpCode]. A correct verification signs in via Supabase's
/// **anonymous auth** (`signInAnonymously`) rather than email/password —
/// deliberately, after email/password kept triggering Supabase's own
/// confirmation-email machinery (rate limits, then SMTP failures) even with
/// "Confirm email" off. Anonymous auth needs no email or SMS provider at
/// all: it hands back a real, persistent `auth.users` row and session,
/// which is all RLS and every other repository actually need — the phone
/// number itself is stored as plain data on the `customers` row, not as
/// the identity Supabase authenticates.
///
/// **Trade-off, accepted for this phase**: identity is tied to *this
/// browser's* session, not the phone number. Re-entering the same phone
/// number on a different device/browser (or after clearing site data)
/// creates a new anonymous identity and a new `customers` row, rather than
/// resuming the original one — real cross-device phone-based identity
/// needs either a real SMS/email provider or a server-side admin-API
/// lookup, neither of which exist yet.
///
/// Requires **Authentication > Settings > "Allow anonymous sign-ins"**
/// enabled in the Supabase dashboard.
final class AuthRepositorySupabase implements AuthRepository {
  SupabaseClient get _client => Supabase.instance.client;

  final Map<String, String> _pendingSignInPhones = {};
  final Set<String> _pendingReverificationIds = {};
  int _requestSeq = 0;

  @override
  Future<OtpRequest> requestOtp({
    required String phoneE164,
    OtpChannel channel = OtpChannel.sms,
  }) async {
    final requestId = 'otp_${_requestSeq++}_${phoneE164.hashCode}';
    _pendingSignInPhones[requestId] = phoneE164;
    return OtpRequest(
      requestId: requestId,
      expiresIn: const Duration(minutes: 10),
      resendAfter: const Duration(seconds: 30),
      channelsAvailable: {OtpChannel.sms},
    );
  }

  @override
  Future<Customer> verifyOtp({
    required String requestId,
    required String code,
  }) async {
    final phone = _pendingSignInPhones[requestId];
    if (phone == null) throw const OtpExpiredException();
    if (code.trim() != _fixedOtpCode) {
      throw const OtpInvalidException(attemptsRemaining: 2);
    }
    _pendingSignInPhones.remove(requestId);
    return _signInWithPhone(phone);
  }

  Future<Customer> _signInWithPhone(String phoneE164) async {
    var user = _client.auth.currentUser;
    if (user == null) {
      final AuthResponse res;
      try {
        res = await _client.auth.signInAnonymously();
      } on AuthException catch (e) {
        throw StateError(
          'Supabase anonymous sign-in failed ($e). Check Authentication > '
          'Settings > "Allow anonymous sign-ins" is enabled.',
        );
      }
      user = res.user;
    }
    if (user == null) {
      throw StateError('Supabase anonymous sign-in returned no user.');
    }

    final existing = await _client
        .from('customers')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    final row =
        existing ??
        await _client
            .from('customers')
            .insert({'id': user.id, 'phone_e164': phoneE164})
            .select()
            .single();
    return _customerFromRow(row);
  }

  @override
  Future<Customer> updateProfile({required String name}) async {
    final row = await _client
        .from('customers')
        .update({
          'name': name,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', _requireUserId())
        .select()
        .single();
    return _customerFromRow(row);
  }

  @override
  Future<Customer> updateAccountDetails({
    String? name,
    String? email,
    String? avatarUrl,
    bool clearAvatar = false,
  }) async {
    final update = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (clearAvatar)
        'avatar_url': null
      else if (avatarUrl != null)
        'avatar_url': avatarUrl,
    };
    final row = await _client
        .from('customers')
        .update(update)
        .eq('id', _requireUserId())
        .select()
        .single();
    return _customerFromRow(row);
  }

  @override
  Future<OtpRequest> requestReverificationOtp() async {
    final requestId = 'reverify_${_requestSeq++}';
    _pendingReverificationIds.add(requestId);
    return OtpRequest(
      requestId: requestId,
      expiresIn: const Duration(minutes: 10),
      resendAfter: const Duration(seconds: 30),
      channelsAvailable: {OtpChannel.sms},
    );
  }

  @override
  Future<void> verifyReverificationOtp({
    required String requestId,
    required String code,
  }) async {
    if (!_pendingReverificationIds.contains(requestId)) {
      throw const OtpExpiredException();
    }
    if (code.trim() != _fixedOtpCode) {
      throw const OtpInvalidException(attemptsRemaining: 2);
    }
    _pendingReverificationIds.remove(requestId);
  }

  @override
  Future<Customer?> restoreSession() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;
      final row = await _client
          .from('customers')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (row == null) return null;
      return _customerFromRow(row);
    } catch (_) {
      // §5a.1: a corrupted/unreadable session reads as signed out, never
      // an uncaught error at startup.
      return null;
    }
  }

  @override
  Future<void> logout() async {
    await _client.auth.signOut();
  }

  String _requireUserId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('No signed-in Supabase user.');
    return id;
  }
}
