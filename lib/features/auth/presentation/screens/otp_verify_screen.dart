import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:surplus_marketplace/app/router/routes.dart';
import 'package:surplus_marketplace/app/session/session_providers.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/core/utils/formatters.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/components/otp_code_field.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/auth/domain/entities/otp_channel.dart';
import 'package:surplus_marketplace/features/auth/presentation/providers/auth_providers.dart';

/// Verify · resend · voice/WhatsApp fallback (§4.2 `/auth/otp`, §5a.7).
///
/// The escalation ladder assumes SMS will **not** reliably arrive — the
/// TRAI DLT reality (Phase 1 §3.5) — rather than treating that as an edge
/// case: WhatsApp surfaces after the first resend, voice after the second.
class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({
    required this.phoneE164,
    required this.requestId,
    this.redirect,
    super.key,
  });

  final String phoneE164;
  final String requestId;
  final String? redirect;

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  static const _resendWait = Duration(seconds: 30);

  late String _requestId = widget.requestId;
  final _controller = TextEditingController();
  Timer? _ticker;
  Duration _remaining = _resendWait;
  int _resendCount = 0;
  bool _verifying = false;
  String? _errorTitle;
  String? _errorBody;
  Duration? _lockout;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _ticker?.cancel();
    setState(() => _remaining = _resendWait);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining.inSeconds <= 0) {
        _ticker?.cancel();
        return;
      }
      setState(() => _remaining -= const Duration(seconds: 1));
    });
  }

  Future<void> _resend(OtpChannel channel) async {
    try {
      final otpRequest = await ref
          .read(authRepositoryProvider)
          .requestOtp(phoneE164: widget.phoneE164, channel: channel);
      if (!mounted) return;
      setState(() {
        _requestId = otpRequest.requestId;
        _resendCount++;
        _errorTitle = null;
        _errorBody = null;
        _controller.clear();
      });
      _startCountdown();
    } on Object {
      // A real SMS-provider/rate-limit failure surfaces once an HTTP
      // AuthRepository can distinguish it from a generic network error.
    }
  }

  Future<void> _verify(String code) async {
    setState(() {
      _verifying = true;
      _errorTitle = null;
      _errorBody = null;
      _lockout = null;
    });
    final l10n = AppLocalizations.of(context);
    try {
      final customer = await ref
          .read(authRepositoryProvider)
          .verifyOtp(requestId: _requestId, code: code);
      if (!mounted) return;
      ref
          .read(sessionStateProvider)
          .markAuthenticated(isProfileComplete: customer.isProfileComplete);
      final redirect = widget.redirect;
      if (!customer.isProfileComplete) {
        ProfileSetupRoute(redirectTo: redirect).go(context);
      } else if (redirect != null &&
          redirect.startsWith('/') &&
          !redirect.startsWith('//')) {
        context.go(redirect);
      } else {
        context.go('/discover');
      }
    } on OtpInvalidException catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _controller.clear();
        _errorTitle = l10n.otpInvalidTitle;
        _errorBody = l10n.otpAttemptsLeft(e.attemptsRemaining);
      });
    } on OtpExpiredException {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _controller.clear();
        _errorTitle = l10n.otpExpiredTitle;
        _errorBody = l10n.otpExpiredBody;
      });
    } on OtpAttemptsExhaustedException catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _controller.clear();
        _errorTitle = l10n.otpExhaustedTitle;
        _lockout = e.retryAfter;
        _errorBody = l10n.otpExhaustedBody(Fmt.countdown(e.retryAfter));
      });
    } on Object {
      if (!mounted) return;
      // A real backend call (Supabase sign-in/up) sits behind verifyOtp
      // now, not just the fixed-vocabulary OTP exceptions above — an
      // unrecognised failure must still say *something*, rather than
      // silently stopping the spinner and leaving the screen looking like
      // the tap did nothing.
      setState(() {
        _verifying = false;
        _controller.clear();
        _errorTitle = l10n.errorServerTitle;
        _errorBody = l10n.errorServerBody;
      });
    }
  }

  String get _maskedPhone {
    final digits = widget.phoneE164;
    if (digits.length < 4) return digits;
    return '+91 ${'*' * 6}${digits.substring(digits.length - 2)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final resendReady = _remaining.inSeconds <= 0 && _lockout == null;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(backgroundColor: colors.surfaceBase, elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.x6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.otpVerifyHeadline, style: context.type.display),
              const SizedBox(height: Space.x2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.otpVerifySentTo(_maskedPhone),
                      style: context.type.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text(l10n.otpChangeNumber),
                  ),
                ],
              ),
              const SizedBox(height: Space.x6),
              OtpCodeField(
                length: 6,
                controller: _controller,
                semanticLabel: l10n.otpFieldSemanticLabel,
                autofocus: true,
                onCompleted: _lockout == null ? _verify : null,
              ),
              if (_errorTitle != null) ...[
                const SizedBox(height: Space.x4),
                Semantics(
                  liveRegion: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _errorTitle!,
                        style: context.type.body.copyWith(
                          color: colors.critical.fg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _errorBody!,
                        style: context.type.body.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: Space.x6),
              if (_lockout == null) ...[
                Semantics(
                  liveRegion: true,
                  label: resendReady
                      ? l10n.otpResend
                      : l10n.otpResendIn(_remaining.inSeconds),
                  excludeSemantics: true,
                  child: TextButton(
                    onPressed: resendReady
                        ? () => _resend(OtpChannel.sms)
                        : null,
                    child: Text(
                      resendReady
                          ? l10n.otpResend
                          : l10n.otpResendIn(_remaining.inSeconds),
                    ),
                  ),
                ),
                if (_resendCount >= 1)
                  TextButton(
                    onPressed: resendReady
                        ? () => _resend(OtpChannel.whatsapp)
                        : null,
                    child: Text(l10n.otpTryWhatsApp),
                  ),
                if (_resendCount >= 2)
                  TextButton(
                    onPressed: resendReady
                        ? () => _resend(OtpChannel.voice)
                        : null,
                    child: Text(l10n.otpTryVoice),
                  ),
              ],
              const Spacer(),
              AppButton(
                label: l10n.otpVerifyCta,
                isLoading: _verifying,
                onPressed: _lockout != null || _controller.text.length != 6
                    ? null
                    : () => _verify(_controller.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
