import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/design_system/components/app_button.dart';
import 'package:too_good_to_leave_shop/design_system/components/hero_visual.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/breakpoints.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';

/// The very first screen a shop owner sees — a choice between logging in
/// to an existing account and registering a brand-new shop. Shown whenever
/// there's no local profile at all, the same slot the registration form
/// used to occupy on its own.
///
/// Deliberately callback-driven rather than pushing its own routes —
/// `main.dart`'s single reactive `ListenableBuilder` is what decides which
/// screen is visible everywhere else in this app (registration completing,
/// logging out, etc. all just flow from repository state changes), and a
/// `Navigator.push` here would leave a stale route sitting on top of that
/// once the underlying state moves on.
class LoginOrRegisterScreen extends StatelessWidget {
  const LoginOrRegisterScreen({
    required this.onChooseLogin,
    required this.onChooseRegister,
    super.key,
  });

  final VoidCallback onChooseLogin;
  final VoidCallback onChooseRegister;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDesktop = context.isDesktopWidth;

    final content = Padding(
      padding: const EdgeInsets.all(Space.x6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome', style: context.type.display),
          const SizedBox(height: Space.x2),
          Text(
            'Log in to an existing shop, or register a new one to start '
            'listing surplus bags.',
            style: context.type.bodyLarge.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: Space.x8),
          AppButton(label: 'Log in', onPressed: onChooseLogin),
          const SizedBox(height: Space.x3),
          AppButton(
            label: 'Register your business',
            variant: AppButtonVariant.secondary,
            onPressed: onChooseRegister,
          ),
        ],
      ),
    );

    if (!isDesktop) {
      return Scaffold(
        backgroundColor: colors.surfaceBase,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(
                  height: 260,
                  child: HeroVisual(
                    title: 'Too Good To Leave',
                    subtitle: 'List your surplus. Reach real customers, fast.',
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: Breakpoints.formMaxWidth,
                    ),
                    child: content,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 11,
            child: SafeArea(
              child: Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: Breakpoints.formMaxWidth,
                  ),
                  child: content,
                ),
              ),
            ),
          ),
          const Expanded(
            flex: 9,
            child: HeroVisual(
              title: 'Too Good To Leave',
              subtitle: 'List your surplus. Reach real customers, fast.',
            ),
          ),
        ],
      ),
    );
  }
}
