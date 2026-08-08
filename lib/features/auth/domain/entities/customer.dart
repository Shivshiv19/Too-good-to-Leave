/// The signed-in customer (Phase 5a §5a.6–§5a.8, extended by Phase 8 §8.12
/// step 9 — Account).
final class Customer {
  const Customer({
    required this.id,
    required this.phoneE164,
    this.name,
    this.email,
    this.avatarUrl,
  });

  /// Server-assigned opaque ID.
  final String id;

  /// E.164, e.g. `+919812345678`. **Read-only in V1** (§5f.2) — changing it
  /// is an identity change needing OTP verification on both numbers plus
  /// account-takeover protection, deliberately deferred.
  final String phoneE164;

  /// Null until profile setup (§5a.8) completes.
  final String? name;

  /// Optional — collected for receipts only (§5f.2), never required.
  final String? email;

  /// A `data:` URI in this fake (no real upload endpoint exists) or an
  /// `https:` URL against a real backend — `AvatarImage` (design system)
  /// renders either.
  final String? avatarUrl;

  /// §4.3 rule 8 — whether `/auth/profile-setup` still needs to run.
  bool get isProfileComplete => name != null && name!.trim().isNotEmpty;

  Customer copyWith({
    String? name,
    String? email,
    String? avatarUrl,
    bool clearAvatar = false,
  }) => Customer(
    id: id,
    phoneE164: phoneE164,
    name: name ?? this.name,
    email: email ?? this.email,
    avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
  );

  @override
  bool operator ==(Object other) =>
      other is Customer &&
      other.id == id &&
      other.phoneE164 == phoneE164 &&
      other.name == name &&
      other.email == email &&
      other.avatarUrl == avatarUrl;

  @override
  int get hashCode => Object.hash(id, phoneE164, name, email, avatarUrl);
}
