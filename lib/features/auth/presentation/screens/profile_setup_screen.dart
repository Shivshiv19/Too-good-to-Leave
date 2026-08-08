import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:surplus_marketplace/app/session/session_providers.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/auth/presentation/providers/auth_providers.dart';

/// Name only (§4.2 `/auth/profile-setup`, §5a.8).
///
/// **One field, deliberately.** The user is mid-reservation with a live
/// cart hold counting down (once `checkout` exists); every extra field here
/// is friction at peak abandonment risk. Email, photo, and preferences are
/// all deferred to Account.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({this.redirect, super.key});

  final String? redirect;

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isValid {
    final name = _controller.text.trim();
    if (name.length < 2 || name.length > 50) return false;
    // Unicode letters permitted (§5a.8) — a Latin-only regex would reject a
    // large share of Indian users' actual names. Rejects digit-only input
    // and anything URL-shaped by requiring at least one letter.
    return RegExp(r'[^\d\s]').hasMatch(name) && !name.contains('://');
  }

  Future<void> _submit() async {
    if (!_isValid) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .updateProfile(name: _controller.text.trim());
      if (!mounted) return;
      ref.read(sessionStateProvider).markProfileComplete();
      final redirect = widget.redirect;
      if (redirect != null &&
          redirect.startsWith('/') &&
          !redirect.startsWith('//')) {
        context.go(redirect);
      } else {
        context.go('/discover');
      }
    } on Object {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.x6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l10n.profileSetupHeadline, style: context.type.display),
              const SizedBox(height: Space.x6),
              TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                maxLength: 50,
                inputFormatters: [LengthLimitingTextInputFormatter(50)],
                decoration: InputDecoration(
                  labelText: l10n.profileSetupNameLabel,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: Space.x6),
              AppButton(
                label: l10n.continueCta,
                isLoading: _submitting,
                onPressed: _isValid && !_submitting ? _submit : null,
                disabledReason: l10n.profileSetupNameInvalid,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
