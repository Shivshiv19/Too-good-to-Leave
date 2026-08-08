import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/components/app_button.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/screens/edit_profile_screen.dart';

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
              const SizedBox(height: Space.x3),
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
