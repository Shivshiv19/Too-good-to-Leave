/// An in-app notification derived from a real action taken during this
/// session (a payout requested, a pickup confirmed, a no-show recorded,
/// ...) — not a simulated push feed. This app has no push infrastructure
/// (the customer app's own docs note the same gap: no push simulator
/// exists), so a feed of genuinely-happened events is the honest
/// alternative to fabricating fake historical notifications.
final class ShopNotification {
  const ShopNotification({
    required this.id,
    required this.message,
    required this.createdAt,
    this.read = false,
  });

  final String id;
  final String message;
  final DateTime createdAt;
  final bool read;

  ShopNotification copyWith({bool? read}) => ShopNotification(
    id: id,
    message: message,
    createdAt: createdAt,
    read: read ?? this.read,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'message': message,
    'createdAt': createdAt.toIso8601String(),
    'read': read,
  };

  factory ShopNotification.fromJson(Map<String, dynamic> json) =>
      ShopNotification(
        id: json['id'] as String,
        message: json['message'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        read: json['read'] as bool? ?? false,
      );
}
