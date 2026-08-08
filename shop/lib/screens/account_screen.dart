import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/components/app_button.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/screens/edit_profile_screen.dart';
import 'package:too_good_to_leave_shop/screens/notifications_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({required this.repository, super.key});

  final ShopRepository repository;

  Future<void> _confirmLogOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'This clears your registration and listings from this browser. '
          "You'll need to register again to come back.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await repository.logOut();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        final profile = repository.profile!;
        return Scaffold(
          backgroundColor: colors.surfaceBase,
          appBar: AppBar(
            backgroundColor: colors.surfaceBase,
            title: Text('Account', style: context.type.title),
          ),
          body: ListView(
            padding: const EdgeInsets.all(Space.x4),
            children: [
              Container(
                padding: const EdgeInsets.all(Space.x4),
                decoration: BoxDecoration(
                  color: colors.surfaceRaised,
                  borderRadius: BorderRadius.circular(Radii.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.businessName, style: context.type.headline),
                    const SizedBox(height: Space.x1),
                    Text(
                      profile.category.label,
                      style: context.type.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: Space.x4),
                    _InfoRow(label: 'Owner', value: profile.ownerName),
                    _InfoRow(label: 'Phone', value: profile.phone),
                    _InfoRow(label: 'Email', value: profile.email),
                    _InfoRow(
                      label: 'Address',
                      value: '${profile.addressLine}, ${profile.locality}',
                    ),
                    _InfoRow(
                      label: 'FSSAI licence',
                      value: profile.fssai.licenseNumber,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.x4),
              AppButton(
                label: 'Edit business details',
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) =>
                        EditProfileScreen(repository: repository),
                  ),
                ),
              ),
              const SizedBox(height: Space.x6),
              _NavRow(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                badgeCount: repository.unreadNotificationCount,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) =>
                        NotificationsScreen(repository: repository),
                  ),
                ),
              ),
              const SizedBox(height: Space.x6),
              AppButton(
                label: 'Log out',
                variant: AppButtonVariant.destructive,
                onPressed: () => _confirmLogOut(context),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.surfaceRaised,
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.x4,
            vertical: Space.x3,
          ),
          child: Row(
            children: [
              Icon(icon, color: colors.textSecondary),
              const SizedBox(width: Space.x3),
              Expanded(child: Text(label, style: context.type.body)),
              if (badgeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.x2,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.critical.bg,
                    borderRadius: BorderRadius.circular(Radii.full),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: context.type.caption.copyWith(
                      color: colors.critical.fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Icon(Icons.chevron_right, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: Space.x2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: context.type.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
          Expanded(child: Text(value, style: context.type.body)),
        ],
      ),
    );
  }
}
