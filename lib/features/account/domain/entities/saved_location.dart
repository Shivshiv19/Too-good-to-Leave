import 'package:surplus_marketplace/features/location/domain/entities/resolved_location.dart';

/// §5f.3 — a *named, reusable* discovery anchor ("Home", "Work"), distinct
/// from `location`'s own single "current anchor" concept
/// (`LocationRepository.cachedLocation`). Reuses [ResolvedLocation] for the
/// place itself rather than a second address shape.
final class SavedLocation {
  const SavedLocation({
    required this.id,
    required this.label,
    required this.location,
    required this.isDefault,
  });

  final String id;

  /// User-authored, ≤ 30 characters (§5f.3's validation rule).
  final String label;

  final ResolvedLocation location;
  final bool isDefault;

  SavedLocation copyWith({String? label, bool? isDefault}) => SavedLocation(
    id: id,
    label: label ?? this.label,
    location: location,
    isDefault: isDefault ?? this.isDefault,
  );
}
