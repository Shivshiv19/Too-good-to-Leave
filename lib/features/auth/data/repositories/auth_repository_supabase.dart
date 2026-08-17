import 'package:supabase_flutter/supabase_flutter.dart' hide OtpChannel;
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/core/storage/prefs.dart';
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
///
/// **Google sign-in** ([signInWithGoogle]) is a genuinely different
/// identity path, not another route to the same anonymous trick above: it
/// calls Supabase's real OAuth flow, which on web means the tab navigates
/// away to Google and back with a real, non-anonymous `auth.users` row
/// already established by the time the app reloads. That user has no
/// `customers` row yet, so [restoreSession] reports them as signed out —
/// same as anyone else who hasn't finished signup — and the ordinary
/// phone-entry/OTP screens pick them back up from there. The only branch
/// this adds is in [_signInWithPhone]: when `auth.currentUser` is already a
/// real (non-anonymous) session — i.e. someone arrived via Google, not
/// `signInAnonymously` — it skips minting a new anonymous identity and
/// attaches the phone number they type to that existing Google identity
/// instead, pre-filling name/email/avatar from what Google already told us
/// rather than asking them to retype it.
///
/// **`logout` never calls Supabase's real `signOut`.** An anonymous
/// identity has no password/email to sign back in *with* — actually ending
/// the session would make [logout] permanently and silently destroy the
/// customer's entire order history on this device, directly contradicting
/// the sign-out dialog's own "your orders and reservations aren't
/// affected" copy. Instead [logout] sets a local-only "appears signed out"
/// flag ([_prefs]) that [restoreSession] honours; the underlying anonymous
/// session stays alive in browser storage so re-verifying with the same
/// phone number + OTP on this same device/browser resumes the exact same
/// account rather than minting a new empty one. (Cross-device/browser
/// identity continuity remains out of scope either way — see the class
/// doc above.)
final class AuthRepositorySupabase implements AuthRepository {
  /// [_prefs] backs the local-only "appears signed out" flag — see the
  /// class doc.
  AuthRepositorySupabase(this._prefs);

  static const _locallySignedOutKey = 'auth.locallySignedOut';

  SupabaseClient get _client => Supabase.instance.client;

  final Prefs _prefs;
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
    // A successful verification always means "resume/create my account
    // now" — clear the local-only sign-out flag so `restoreSession` (and
    // anything else that reads it) sees this session as live again.
    await _prefs.setBool(_locallySignedOutKey, value: false);
    var user = _client.auth.currentUser;
    // A real (non-anonymous) session here means signInWithGoogle already
    // ran and the tab came back — this phone number is being attached to
    // that Google identity, not starting a fresh anonymous one.
    final arrivedViaGoogle = user != null && !user.isAnonymous;
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
            .insert({
              'id': user.id,
              'phone_e164': phoneE164,
              // Google already told us who they are — reuse it instead of
              // asking them to retype their name on the next screen.
              if (arrivedViaGoogle) ..._googleProfileFields(user),
            })
            .select()
            .single();
    return _customerFromRow(row);
  }

  Map<String, dynamic> _googleProfileFields(User user) {
    final metadata = user.userMetadata ?? const {};
    return {
      'name': metadata['full_name'] ?? metadata['name'],
      'email': metadata['email'] ?? user.email,
      'avatar_url': metadata['avatar_url'] ?? metadata['picture'],
    };
  }

  @override
  Future<void> signInWithGoogle() async {
    await _prefs.setBool(_locallySignedOutKey, value: false);
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: Uri.base.origin,
    );
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
      if (_prefs.getBool(_locallySignedOutKey) ?? false) return null;
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
    // See the class doc — deliberately not `_client.auth.signOut()`.
    await _prefs.setBool(_locallySignedOutKey, value: true);
  }

  String _requireUserId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('No signed-in Supabase user.');
    return id;
  }
}
