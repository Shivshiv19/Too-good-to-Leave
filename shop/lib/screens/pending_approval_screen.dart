import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/components/app_button.dart';
import 'package:too_good_to_leave_shop/design_system/components/hero_visual.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/breakpoints.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/domain/shop_profile.dart';

/// Shown between submitting registration and a review clearing it — and,
/// for a rejected/deactivated shop, shown again with the reason instead of
/// "under review" (this screen renders for any non-verified status, per
/// `main.dart`'s reactive builder). Approval itself only ever happens from
/// the back office now — there is no self-service shortcut here.
class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({required this.repository, super.key});

  final ShopRepository repository;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final profile = repository.profile!;
    final isDesktop = context.isDesktopWidth;
    final isRejected = profile.status == ShopApprovalStatus.rejected;

    final content = Padding(
      padding: const EdgeInsets.all(Space.x6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isRejected ? Icons.block_outlined : Icons.hourglass_top,
            size: 48,
            color: isRejected ? colors.critical.fg : colors.attention.fg,
          ),
          const SizedBox(height: Space.x4),
          Text(
            isRejected ? 'Not approved' : 'Under review',
            style: context.type.headline,
          ),
          const SizedBox(height: Space.x2),
          Text(
            isRejected
                ? "${profile.businessName} isn't listing right now. "
                      '${profile.rejectionReason?.trim().isNotEmpty ?? false ? profile.rejectionReason! : 'Contact support for details.'}'
                : "Thanks, ${profile.businessName}. We're reviewing your "
                      'FSSAI licence and details — this usually takes 1–2 '
                      'business days. You can list bags and manage orders '
                      "once you're approved.",
            style: context.type.body.copyWith(color: colors.textSecondary),
          ),
          if (isRejected) ...[
            const SizedBox(height: Space.x6),
            AppButton(
              label: 'Log out',
              variant: AppButtonVariant.secondary,
              onPressed: repository.logOut,
            ),
          ],
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
                SizedBox(
                  height: 220,
                  child: HeroVisual(
                    icon: isRejected
                        ? Icons.block_outlined
                        : Icons.hourglass_top_rounded,
                    title: isRejected ? "Not approved" : 'Almost there',
                    subtitle: isRejected
                        ? "This shop isn't currently listing."
                        : "We're reviewing your shop's details.",
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
          Expanded(
            flex: 9,
            child: HeroVisual(
              icon: isRejected
                  ? Icons.block_outlined
                  : Icons.hourglass_top_rounded,
              title: isRejected ? "Not approved" : 'Almost there',
              subtitle: isRejected
                  ? "This shop isn't currently listing."
                  : "We're reviewing your shop's details.",
            ),
          ),
        ],
      ),
    );
  }
}
