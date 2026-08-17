import 'package:surplus_marketplace/features/auth/domain/entities/customer.dart';
import 'package:surplus_marketplace/features/auth/domain/entities/otp_channel.dart';
import 'package:surplus_marketplace/features/auth/domain/entities/otp_request.dart';

/// Phone/OTP authentication (Phase 5a §5a.6–§5a.8, Phase 7 §7.2).
///
/// `presentation` depends only on this abstraction (§8.1); the fake binding
/// is used in the `dev` flavour, an HTTP binding is added once a backend
/// exists (§8.6).
abstract interface class AuthRepository {
  /// `POST /v1/auth/otp/request` (§7.2.1). Called on phone submit and on
  /// every resend — each call issues a fresh [OtpRequest.requestId].
  Future<OtpRequest> requestOtp({
    required String phoneE164,
    OtpChannel channel = OtpChannel.sms,
  });

  /// `POST /v1/auth/otp/verify` (§7.2.2, idempotent). Throws
  /// `OtpInvalidException`, `OtpExpiredException`, or
  /// `OtpAttemptsExhaustedException` (`core/error/app_exception.dart`) on
  /// rejection.
  Future<Customer> verifyOtp({required String requestId, required String code});

  /// `PUT /me` equivalent for §5a.8 — the one field profile setup owns.
  Future<Customer> updateProfile({required String name});

  /// `PATCH /v1/me` (§5f.2) — Account's edit-profile screen. `phoneE164` is
  /// deliberately not a parameter here (§5f.2 — read-only in V1). Passing
  /// `clearAvatar: true` removes the avatar; a non-null [avatarUrl]
  /// otherwise replaces it.
  Future<Customer> updateAccountDetails({
    String? name,
    String? email,
    String? avatarUrl,
    bool clearAvatar = false,
  });

  /// **§5f.11's re-verification** — proves possession of the phone number
  /// before a destructive account action, distinct from [requestOtp]/
  /// [verifyOtp]'s sign-in flow: it targets the **already-signed-in**
  /// customer's own number rather than establishing a new session.
  Future<OtpRequest> requestReverificationOtp();

  /// Throws the same OTP exceptions as [verifyOtp]. Returns nothing on
  /// success — this only proves possession; it does not itself perform
  /// whatever sensitive action needed the proof.
  Future<void> verifyReverificationOtp({
    required String requestId,
    required String code,
  });

  /// Reads whatever session state persists locally (§5a.1) — tokens plus
  /// the customer they belong to. Returns null when signed out.
  ///
  /// Must not throw: a corrupted or unreadable local session is signed-out,
  /// per §5a.1's "secure storage read fails → treat as signed out" rule.
  Future<Customer?> restoreSession();

  /// Google sign-in, offered alongside phone entry rather than replacing
  /// it. On web this navigates the tab away to Google's consent screen and
  /// back — the caller gets no [Customer] back directly. The app resumes
  /// on reload already identified by Google but without a phone number on
  /// file yet, and is routed through the same phone-entry/OTP screens a
  /// first-time phone signup uses to collect one — see the Supabase
  /// binding's class doc for the full handoff.
  Future<void> signInWithGoogle();

  /// `POST /v1/auth/logout` (§7.2.5). Clears all local session state.
  Future<void> logout();
}
