import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:surplus_marketplace/app/router/routes.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/auth/presentation/providers/auth_providers.dart';

/// E.164 entry, begun at the point of highest intent (§4.2 `/auth/phone`,
/// A4 — the wall sits at add-to-cart, not at launch).
class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({this.redirect, super.key});

  /// Where to return to once auth completes. Carried through
  /// `/auth/otp` → `/auth/profile-setup` (§4.3 destination preservation).
  final String? redirect;

  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _submitting = false;
  bool _googleSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Strips spaces, hyphens, a leading `+91`, and a leading `0` — users
  /// paste numbers in every conceivable format (§5a.6).
  String _sanitize(String raw) {
    var digits = raw.replaceAll(RegExp('[^0-9]'), '');
    if (digits.startsWith('91') && digits.length > 10) {
      digits = digits.substring(digits.length - 10);
    }
    if (digits.startsWith('0') && digits.length == 11) {
      digits = digits.substring(1);
    }
    return digits;
  }

  bool _isValid(String digits) =>
      digits.length == 10 && RegExp('^[6-9]').hasMatch(digits);

  Future<void> _submit() async {
    final digits = _sanitize(_controller.text);
    final l10n = AppLocalizations.of(context);
    if (!_isValid(digits)) {
      setState(() => _error = l10n.phoneEntryInvalidNumber);
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    final phoneE164 = '+91$digits';
    try {
      final otpRequest = await ref
          .read(authRepositoryProvider)
          .requestOtp(phoneE164: phoneE164);
      if (!mounted) return;
      OtpVerifyRoute(
        phoneE164: phoneE164,
        requestId: otpRequest.requestId,
        redirectTo: widget.redirect,
      ).go(context);
    } on Object {
      if (mounted) setState(() => _submitting = false);
      // A network/rate-limit/SMS-provider failure here is surfaced via the
      // §C5 generic network copy for now — the domain-specific branches
      // (rate limited, SMS provider down) are added once an HTTP
      // AuthRepository exists to actually produce those distinct failures.
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.errorOfflineBody)));
      }
    }
  }

  Future<void> _continueWithGoogle() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _googleSubmitting = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      // On web this line is only reached in the fake/dev handoff — a real
      // Google sign-in navigates the tab away before this returns. Either
      // way, the phone form on this same screen is what collects a phone
      // number next, so there's nowhere further to navigate to here.
      if (mounted) setState(() => _googleSubmitting = false);
    } on Object {
      if (mounted) {
        setState(() => _googleSubmitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.phoneEntryGoogleFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(backgroundColor: colors.surfaceBase, elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.x6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(Space.x3),
                decoration: BoxDecoration(
                  color: colors.info.bg,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Text(
                  l10n.phoneEntryContextBannerDefault,
                  style: context.type.body.copyWith(color: colors.info.fg),
                ),
              ),
              const SizedBox(height: Space.x6),
              Text(l10n.phoneEntryHeadline, style: context.type.display),
              const SizedBox(height: Space.x6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.x3,
                      vertical: Space.x3,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.borderSubtle),
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    child: Text('+91', style: context.type.bodyLarge),
                  ),
                  const SizedBox(width: Space.x3),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [
                        AutofillHints.telephoneNumberNational,
                      ],
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: context.type.bodyLarge,
                      decoration: InputDecoration(
                        labelText: l10n.phoneEntryHeadline,
                        counterText: '',
                        errorText: _error,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Radii.sm),
                        ),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.x6),
              Text(
                l10n.phoneEntryTermsConsent,
                style: context.type.caption.copyWith(
                  color: colors.textTertiary,
                ),
              ),
              const SizedBox(height: Space.x4),
              AppButton(
                label: l10n.continueCta,
                isLoading: _submitting,
                onPressed: _submitting || _googleSubmitting ? null : _submit,
              ),
              const SizedBox(height: Space.x5),
              Row(
                children: [
                  Expanded(child: Divider(color: colors.borderSubtle)),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.x3,
                    ),
                    child: Text(
                      l10n.phoneEntryOrDivider,
                      style: context.type.caption.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: colors.borderSubtle)),
                ],
              ),
              const SizedBox(height: Space.x5),
              AppButton(
                label: l10n.phoneEntryGoogleCta,
                variant: AppButtonVariant.secondary,
                isLoading: _googleSubmitting,
                onPressed: _submitting || _googleSubmitting
                    ? null
                    : _continueWithGoogle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
