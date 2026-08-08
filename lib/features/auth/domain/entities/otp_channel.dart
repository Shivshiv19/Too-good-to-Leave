/// Delivery channel for an OTP (Phase 5a §5a.6, Phase 1 §3.5 TRAI DLT
/// reality).
enum OtpChannel {
  sms('sms'),
  whatsapp('whatsapp'),
  voice('voice');

  const OtpChannel(this.wireValue);

  final String wireValue;

  /// Tolerant decoder (Phase 7 §7.1.4). Falls back to [sms] — the channel
  /// every request already tries first, so an unrecognised value degrades to
  /// what the user was going to get anyway.
  static OtpChannel fromWire(String? value) => OtpChannel.values.firstWhere(
    (c) => c.wireValue == value,
    orElse: () => OtpChannel.sms,
  );
}
