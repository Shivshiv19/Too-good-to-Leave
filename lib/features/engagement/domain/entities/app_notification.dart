import 'package:surplus_marketplace/features/engagement/domain/entities/notification_class.dart';
import 'package:surplus_marketplace/features/engagement/domain/entities/notification_type.dart';

/// Phase 2 §2.1's `AppNotification` — the durable record §5e.1 exists for.
///
/// [title]/[body] arrive as **server-composed strings**, not client
/// templates (§7.8's push payload contract carries them directly) — this
/// mirrors the wire shape rather than reconstructing copy client-side from
/// [type] and typed data.
final class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.notificationClass,
    required this.title,
    required this.body,
    required this.route,
    required this.createdAt,
    required this.read,
    required this.dismissible,
    this.orderId,
  });

  final String id;
  final NotificationType type;
  final NotificationClass notificationClass;
  final String title;
  final String body;

  /// **Validated against the route table before navigation** (§4.3) — an
  /// unvalidated route from a remote payload is an open-redirect primitive.
  /// Validation is the router's job at the point of navigation; this field
  /// only carries the intended destination.
  final String route;

  final String? orderId;
  final DateTime createdAt;
  final bool read;

  /// False for a transactional notice whose order is still live (§5e.1) —
  /// the record of a financial commitment is not swipe-able into oblivion
  /// while that commitment is open.
  final bool dismissible;
}
