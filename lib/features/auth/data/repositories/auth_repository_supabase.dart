import 'package:supabase_flutter/supabase_flutter.dart' hide OtpChannel;
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/features/auth/auth.dart';

/// Fixed 6-digit code accepted for every OTP verification — the app's own
/// scoping decision (real Supabase Auth session + real data everywhere
/// else, but no real SMS provider): "we can use hardcoded OTP". Never
/// generated, never sent anywhere; [AuthRepositorySupabase.requestOtp]
/// doesn't dispatch an SMS at all.
const _fixedOtpCode = '123456';

/// Fixed placeholder password paired with a synthetic per-customer email —
/// the phone number is the real identity; this just satisfies Supabase
/// Auth's email/password shape without a real password ever existing.
const _fixedPassword = 'Tgtl-Customer-Fixed-Pw-2026!';

String _syntheticEmail(String phoneE164) {
  final digits = phoneE164.replaceAll(RegExp(r'[^0-9]'), '');
  return 'cust.$digits@toogoodtoleave.local';
}

bool _isAlreadyRegistered(AuthException e) =>
    e.message.toLowerCase().contains('already registered') ||
    e.message.toLowerCase().contains('already exists') ||
    e.code == 'user_already_exists';

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
/// always [_fixedOtpCode] — but a correct verification performs a real
/// Supabase `signUp`/`signInWithPassword` (phone formatted as a synthetic
/// email, see [_syntheticEmail]) and creates/reads a real row in the shared
/// `customers` table (`supabase/schema.sql`), so the resulting session and
/// customer id are exactly what RLS and every other repository expect.
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
    final email = _syntheticEmail(phoneE164);
    AuthResponse res;
    try {
      res = await _client.auth.signUp(email: email, password: _fixedPassword);
    } on AuthException catch (e) {
      if (!_isAlreadyRegistered(e)) rethrow;
      res = await _client.auth.signInWithPassword(
        email: email,
        password: _fixedPassword,
      );
    }
    if (res.session == null) {
      // Supabase's default "Confirm email" setting blocks sign-in until a
      // confirmation link is clicked — impossible for these synthetic
      // per-customer emails. Must be off: Supabase dashboard >
      // Authentication > Sign In / Providers > Email > "Confirm email".
      try {
        res = await _client.auth.signInWithPassword(
          email: email,
          password: _fixedPassword,
        );
      } on AuthException catch (e) {
        throw StateError(
          'Supabase sign-in failed ($e). If this says "Email not '
          'confirmed", turn off Authentication > Providers > Email > '
          '"Confirm email" in the Supabase dashboard — synthetic '
          'per-customer emails can never confirm.',
        );
      }
    }
    final user = res.user;
    if (user == null) {
      throw StateError('Supabase authentication returned no user for $email.');
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
