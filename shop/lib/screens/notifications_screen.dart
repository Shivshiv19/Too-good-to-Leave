import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/domain/shop_notification.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({required this.repository, super.key});

  final ShopRepository repository;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Opening the list is the "read" action — matches how a bell icon's
    // badge normally clears once you've actually looked at the feed.
    widget.repository.markAllNotificationsRead();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final notifications = widget.repository.getNotifications();

        return Scaffold(
          backgroundColor: colors.surfaceBase,
          appBar: AppBar(
            backgroundColor: colors.surfaceBase,
            title: Text('Notifications', style: context.type.title),
          ),
          body: notifications.isEmpty
              ? Center(
                  child: Text(
                    "Nothing yet — this fills in as you confirm pickups, "
                    'record no-shows, and request payouts.',
                    textAlign: TextAlign.center,
                    style: context.type.body.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(Space.x4),
                  itemCount: notifications.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.x3),
                  itemBuilder: (context, index) =>
                      _NotificationTile(notification: notifications[index]),
                ),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final ShopNotification notification;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final time = notification.createdAt;

    return Container(
      padding: const EdgeInsets.all(Space.x4),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.card),
        border: notification.read
            ? null
            : Border.all(color: colors.actionPrimaryBg, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications_outlined, color: colors.textSecondary),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notification.message, style: context.type.body),
                const SizedBox(height: Space.x1),
                Text(
                  '${time.hour.toString().padLeft(2, '0')}:'
                  '${time.minute.toString().padLeft(2, '0')} · '
                  '${time.day}/${time.month}/${time.year}',
                  style: context.type.caption.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
