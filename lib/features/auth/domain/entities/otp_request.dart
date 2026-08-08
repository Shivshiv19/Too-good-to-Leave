import 'package:surplus_marketplace/features/auth/domain/entities/otp_channel.dart';

/// Response to `POST /v1/auth/otp/request` (Phase 7 §7.2.1).
///
/// [channelsAvailable] drives the §5a.7 escalation ladder — the client
/// offers WhatsApp and voice **only when the server says they will work**,
/// never advertising a channel that will silently fail (the TRAI DLT
/// reality, Phase 1 §3.5).
final class OtpRequest {
  const OtpRequest({
    required this.requestId,
    required this.expiresIn,
    required this.resendAfter,
    required this.channelsAvailable,
  });

  final String requestId;

  /// Code validity — 10 minutes per §5a.7.
  final Duration expiresIn;

  /// How long until resend is offered — 30 s per §5a.7.
  final Duration resendAfter;

  final Set<OtpChannel> channelsAvailable;
}
