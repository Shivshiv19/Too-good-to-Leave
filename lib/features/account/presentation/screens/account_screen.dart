import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:surplus_marketplace/app/router/routes.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/core/utils/formatters.dart';
import 'package:surplus_marketplace/design_system/components/account_hero_header.dart';
import 'package:surplus_marketplace/design_system/components/profile_header.dart';
import 'package:surplus_marketplace/design_system/components/settings_list.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/account/presentation/screens/logout_dialog.dart';
import 'package:surplus_marketplace/features/auth/auth.dart';

/// §4.2 `/account`, §5f.1 — identity and navigation hub.
///
/// **Amendment A18** — this root is public. An anonymous user sees a
/// Sign-in prompt instead of a profile, but every public item (App
/// settings, Help, Legal, About) works fully; gated items stay visible
/// and labelled as gated rather than disappearing (§5f.1's own rule
/// against a menu that changes shape after login).
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  Customer? _customer;
  String _versionLine = '';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final customer = await ref.read(authRepositoryProvider).restoreSession();
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _customer = customer;
      _versionLine = 'v${info.version} (${info.buildNumber})';
      _loaded = true;
    });
  }

  void _goOrGate(String redirectTo, VoidCallback goAuthenticated) {
    if (_customer != null) {
      goAuthenticated();
    } else {
      PhoneEntryRoute(redirectTo: redirectTo).go(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final authenticated = _customer != null;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        elevation: 0,
        title: Text(l10n.accountTitle),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.zero,
                children: [
                  authenticated
                      ? AccountHeroHeader(
                          name: _customer!.name ?? '',
                          subtitle: Fmt.maskedPhone(_customer!.phoneE164),
                          avatarUrl: _customer!.avatarUrl,
                          onTap: () => const AccountProfileRoute().go(context),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(Space.x4),
                          child: ProfileHeader.anonymous(
                            signInLabel: l10n.accountSignIn,
                            signInBody: l10n.accountSignInBody,
                            onSignIn: () => const PhoneEntryRoute(
                              redirectTo: '/account',
                            ).go(context),
                          ),
                        ),
                  const SizedBox(height: Space.x4),
                  SettingsGroup(
                    title: l10n.accountGroupAccount,
                    rows: [
                      SettingsRow(
                        icon: Icons.person_outline,
                        label: l10n.accountEditProfile,
                        gated: !authenticated,
                        gatedSemanticSuffix: l10n.accountSignInRequired,
                        onTap: () => _goOrGate(
                          '/account/profile',
                          () => const AccountProfileRoute().go(context),
                        ),
                      ),
                      SettingsRow(
                        icon: Icons.location_on_outlined,
                        label: l10n.accountSavedLocations,
                        gated: !authenticated,
                        gatedSemanticSuffix: l10n.accountSignInRequired,
                        onTap: () => _goOrGate(
                          '/account/locations',
                          () => const AccountLocationsRoute().go(context),
                        ),
                      ),
                    ],
                  ),
                  SettingsGroup(
                    title: l10n.accountGroupPreferences,
                    rows: [
                      SettingsRow(
                        icon: Icons.notifications_outlined,
                        label: l10n.accountNotificationSettings,
                        gated: !authenticated,
                        gatedSemanticSuffix: l10n.accountSignInRequired,
                        onTap: () => _goOrGate(
                          '/account/notifications',
                          () => const AccountNotificationsRoute().go(context),
                        ),
                      ),
                      SettingsRow(
                        icon: Icons.settings_outlined,
                        label: l10n.accountAppSettings,
                        onTap: () => const AccountSettingsRoute().go(context),
                      ),
                    ],
                  ),
                  SettingsGroup(
                    title: l10n.accountGroupSupport,
                    rows: [
                      SettingsRow(
                        icon: Icons.help_outline,
                        label: l10n.accountHelp,
                        onTap: () => const AccountHelpRoute().go(context),
                      ),
                      SettingsRow(
                        icon: Icons.mail_outline,
                        label: l10n.accountContact,
                        onTap: () => const AccountContactRoute().go(context),
                      ),
                    ],
                  ),
                  SettingsGroup(
                    title: l10n.accountGroupAbout,
                    rows: [
                      SettingsRow(
                        icon: Icons.gavel_outlined,
                        label: l10n.accountLegal,
                        onTap: () => const AccountLegalRoute(
                          docId: 'terms',
                        ).go(context),
                      ),
                      SettingsRow(
                        icon: Icons.info_outline,
                        label: l10n.accountAbout,
                        onTap: () => const AccountAboutRoute().go(context),
                      ),
                    ],
                  ),
                  if (authenticated)
                    SettingsGroup(
                      title: '',
                      rows: [
                        SettingsRow(
                          icon: Icons.logout,
                          label: l10n.accountLogOut,
                          onTap: () => showLogoutDialog(context),
                        ),
                        SettingsRow(
                          icon: Icons.delete_outline,
                          label: l10n.accountDeleteAccount,
                          destructive: true,
                          onTap: () => const AccountDeleteRoute().go(context),
                        ),
                      ],
                    ),
                  const SizedBox(height: Space.x6),
                  Center(
                    child: Text(
                      _versionLine,
                      style: context.type.caption.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.x6),
                ],
              ),
      ),
    );
  }
}
