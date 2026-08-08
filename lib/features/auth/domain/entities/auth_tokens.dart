/// Result of `POST /v1/auth/otp/verify` or `/auth/token/refresh` (Phase 7
/// §7.2.2, §7.2.3).
///
/// **Amendment A24 scope note.** Real rotation (single-use refresh, reuse
/// detection revoking the token family) is a `core/network` interceptor
/// concern (Phase 8 §8.2 `auth_interceptor.dart`) that doesn't exist yet —
/// there is no HTTP layer to intercept. This type carries the shape rotation
/// needs; the serialised-refresh behaviour itself lands with the interceptor.
final class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
}
