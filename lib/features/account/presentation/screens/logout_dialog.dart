import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:surplus_marketplace/app/router/routes.dart';
import 'package:surplus_marketplace/app/session/session_providers.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/features/auth/auth.dart';

/// §5f.12 — a dialog, not a route. **Leads with the reassurance that
/// active orders are unaffected** (the §5a.11 anxiety), and clears all
/// local user data on confirm.
Future<void> showLogoutDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => const _LogoutDialog(),
);

class _LogoutDialog extends ConsumerStatefulWidget {
  const _LogoutDialog();

  @override
  ConsumerState<_LogoutDialog> createState() => _LogoutDialogState();
}

class _LogoutDialogState extends ConsumerState<_LogoutDialog> {
  bool _submitting = false;

  Future<void> _confirm() async {
    setState(() => _submitting = true);
    await ref.read(authRepositoryProvider).logout();
    ref.read(sessionStateProvider).markSignedOut();
    if (mounted) {
      Navigator.of(context).pop();
      const DiscoverRoute().go(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.logoutTitle),
      content: Text(l10n.logoutBody),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        AppButton(
          label: l10n.logoutConfirm,
          variant: AppButtonVariant.destructive,
          expand: false,
          isLoading: _submitting,
          onPressed: _submitting ? null : _confirm,
        ),
      ],
    );
  }
}
