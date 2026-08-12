import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/components/app_button.dart';
import 'package:too_good_to_leave_shop/design_system/components/hero_visual.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/breakpoints.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';

/// Shown between submitting registration and a review clearing it. There's
/// no admin/reviewer surface in this standalone build, so the "simulate
/// approval" action stands in for what a real review process would
/// eventually do — without it, this screen would be a dead end no demo
/// could get past.
class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({required this.repository, super.key});

  final ShopRepository repository;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final profile = repository.profile!;
    final isDesktop = context.isDesktopWidth;

    final content = Padding(
      padding: const EdgeInsets.all(Space.x6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.hourglass_top, size: 48, color: colors.attention.fg),
          const SizedBox(height: Space.x4),
          Text('Under review', style: context.type.headline),
          const SizedBox(height: Space.x2),
          Text(
            "Thanks, ${profile.businessName}. We're reviewing your "
            'FSSAI licence and details — this usually takes 1–2 '
            'business days. You can list bags and manage orders once '
            "you're approved.",
            style: context.type.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: Space.x8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Space.x4),
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              borderRadius: BorderRadius.circular(Radii.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Demo shortcut', style: context.type.label),
                const SizedBox(height: Space.x1),
                Text(
                  'There is no real reviewer in this standalone build — '
                  'use this button to approve yourself and continue.',
                  style: context.type.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: Space.x3),
                AppButton(
                  label: 'Simulate approval',
                  variant: AppButtonVariant.secondary,
                  onPressed: repository.simulateApproval,
                ),
              ],
            ),
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
                  height: 220,
                  child: HeroVisual(
                    icon: Icons.hourglass_top_rounded,
                    title: 'Almost there',
                    subtitle: "We're reviewing your shop's details.",
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
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
                alignment: Alignment.centerLeft,
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
              icon: Icons.hourglass_top_rounded,
              title: 'Almost there',
              subtitle: "We're reviewing your shop's details.",
            ),
          ),
        ],
      ),
    );
  }
}
