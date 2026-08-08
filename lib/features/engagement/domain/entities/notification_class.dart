/// §5e.1's retention/dismissal classes.
enum NotificationClass {
  /// Not dismissible while the order is live; retained 30 days after
  /// terminal.
  transactional,

  /// Freely dismissible; auto-expires after 24 h.
  discovery,

  /// Freely dismissible; retained 7 days.
  prompt;

  static NotificationClass fromWire(String value) => switch (value) {
    'discovery' => NotificationClass.discovery,
    'prompt' => NotificationClass.prompt,
    // Conservative fallback — treating an unrecognised class as
    // transactional means it stays visible rather than silently
    // vanishing under a wrong retention rule.
    _ => NotificationClass.transactional,
  };
}
