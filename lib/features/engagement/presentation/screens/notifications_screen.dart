import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/core/utils/formatters.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/components/notification_list_item.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/auth/auth.dart';
import 'package:surplus_marketplace/features/engagement/engagement.dart';

enum _Phase { loading, loaded, error }

/// §4.2 `/notifications`, §5e.1 — a durable record of time-sensitive
/// events, pushed above the shell.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  static const _clock = SystemClock();

  _Phase _phase = _Phase.loading;
  List<AppNotification> _notifications = const [];
  String? _customerId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _phase = _Phase.loading);
    try {
      final customer = await ref.read(authRepositoryProvider).restoreSession();
      if (customer == null) throw StateError('no session');
      final notifications = await ref
          .read(engagementRepositoryProvider)
          .getNotifications(customerId: customer.id);
      if (!mounted) return;
      setState(() {
        _customerId = customer.id;
        _notifications = notifications;
        _phase = _Phase.loaded;
      });
    } on Object {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  Future<void> _markAllRead() async {
    final customerId = _customerId;
    if (customerId == null) return;
    await ref
        .read(engagementRepositoryProvider)
        .markAllRead(customerId: customerId);
    final l10n = AppLocalizations.of(context);
    SemanticsService.announce(
      l10n.notificationsMarkAllReadAnnouncement,
      Directionality.of(context),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        elevation: 0,
        title: Text(l10n.notificationsTitle),
        actions: [
          if (_notifications.any((n) => !n.read))
            TextButton(
              onPressed: _markAllRead,
              child: Text(l10n.notificationsMarkAllRead),
            ),
        ],
      ),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.loading => const Center(child: CircularProgressIndicator()),
          _Phase.error => _ErrorState(onRetry: _load, l10n: l10n),
          _Phase.loaded =>
            _notifications.isEmpty
                ? _Empty(l10n: l10n)
                : _List(
                    notifications: _notifications,
                    clock: _clock,
                    l10n: l10n,
                  ),
        },
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({
    required this.notifications,
    required this.clock,
    required this.l10n,
  });

  final List<AppNotification> notifications;
  final Clock clock;
  final AppLocalizations l10n;

  String _typeTitle(NotificationType type) => switch (type) {
    NotificationType.orderConfirmed => l10n.notifTypeOrderConfirmed,
    NotificationType.paymentFailed => l10n.notifTypePaymentFailed,
    NotificationType.merchantCancelled => l10n.notifTypeMerchantCancelled,
    NotificationType.refundInitiated => l10n.notifTypeRefundInitiated,
    NotificationType.refundCompleted => l10n.notifTypeRefundCompleted,
    NotificationType.pickupWindowOpening => l10n.notifTypePickupWindowOpening,
    NotificationType.pickupClosingSoon => l10n.notifTypePickupClosingSoon,
    NotificationType.rateYourPickup => l10n.notifTypeRateYourPickup,
    NotificationType.newBagsNearby => l10n.notifTypeNewBagsNearby,
    NotificationType.watchedMerchantListed =>
      l10n.notifTypeWatchedMerchantListed,
  };

  String _section(DateTime at) {
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(at.year, at.month, at.day);
    final delta = today.difference(target).inDays;
    if (delta <= 0) return l10n.notificationsSectionToday;
    if (delta == 1) return l10n.notificationsSectionYesterday;
    return l10n.notificationsSectionEarlier;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final grouped = <String, List<AppNotification>>{};
    for (final n in notifications) {
      grouped.putIfAbsent(_section(n.createdAt), () => []).add(n);
    }

    return ListView(
      children: [
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.x4,
              Space.x4,
              Space.x4,
              Space.x1,
            ),
            child: Text(
              entry.key,
              style: context.type.caption.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final n in entry.value)
            NotificationListItem(
              type: n.type,
              title: _typeTitle(n.type),
              body: l10n.notifBodyTemplate(n.title, n.body),
              timeLabel: Fmt.relativeTime(n.createdAt, clock),
              read: n.read,
              semanticLabel: l10n.notifSemantic(
                n.read ? '' : l10n.notifUnreadPrefix,
                _typeTitle(n.type),
                l10n.notifBodyTemplate(n.title, n.body),
                Fmt.absoluteTime(n.createdAt, clock),
              ),
              onTap: () => context.go(n.route),
            ),
        ],
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: colors.textTertiary,
            ),
            const SizedBox(height: Space.x4),
            Text(
              l10n.notificationsEmptyTitle,
              style: context.type.display,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.x2),
            Text(
              l10n.notificationsEmptyBody,
              style: context.type.body.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry, required this.l10n});

  final Future<void> Function() onRetry;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.errorServerTitle,
              style: context.type.display,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.x2),
            Text(
              l10n.errorServerBody,
              style: context.type.body.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.x6),
            AppButton(label: l10n.errorRetry, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
