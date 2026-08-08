import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/engagement/domain/entities/notification_type.dart';

/// One row in the notification centre (§5e.1).
///
/// **Unread state is part of the semantic label, never a coloured dot
/// alone** (§5e.1's own accessibility requirement) — `semanticLabel` is
/// composed by the caller (title, body, relative *and* absolute time,
/// read state) so this component carries no l10n dependency.
class NotificationListItem extends StatelessWidget {
  const NotificationListItem({
    required this.type,
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.read,
    required this.semanticLabel,
    required this.onTap,
    super.key,
  });

  final NotificationType type;
  final String title;
  final String body;
  final String timeLabel;
  final bool read;
  final String semanticLabel;
  final VoidCallback onTap;

  IconData get _icon => switch (type) {
    NotificationType.newBagsNearby => Icons.storefront_outlined,
    NotificationType.watchedMerchantListed =>
      Icons.notifications_active_outlined,
    NotificationType.pickupWindowOpening => Icons.schedule,
    NotificationType.pickupClosingSoon => Icons.timer_outlined,
    NotificationType.orderConfirmed => Icons.check_circle_outline,
    NotificationType.paymentFailed => Icons.error_outline,
    NotificationType.merchantCancelled => Icons.cancel_outlined,
    NotificationType.refundInitiated ||
    NotificationType.refundCompleted => Icons.currency_rupee,
    NotificationType.rateYourPickup => Icons.star_border,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: read ? colors.surfaceBase : colors.info.bg,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.x4,
              vertical: Space.x3,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_icon, color: colors.textSecondary, size: 22),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.type.body.copyWith(
                          fontWeight: read ? FontWeight.w400 : FontWeight.w700,
                        ),
                      ),
                      Text(
                        body,
                        style: context.type.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: Space.x1),
                      Text(
                        timeLabel,
                        style: context.type.caption.copyWith(
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!read) ...[
                  const SizedBox(width: Space.x2),
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: Space.x1),
                    decoration: BoxDecoration(
                      color: colors.info.fg,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
