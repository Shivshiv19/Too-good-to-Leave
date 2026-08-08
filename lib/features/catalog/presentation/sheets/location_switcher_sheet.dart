import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:surplus_marketplace/app/session/session_providers.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/core/platform/location_capability.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/location/domain/entities/location_precision.dart';
import 'package:surplus_marketplace/features/location/domain/entities/location_source.dart';
import 'package:surplus_marketplace/features/location/domain/entities/resolved_location.dart';
import 'package:surplus_marketplace/features/location/presentation/providers/location_providers.dart';

/// §5b.6 — bottom sheet, no route. Changes the discovery anchor without
/// leaving Discover.
///
/// **Scope note.** Saved locations (authenticated only) belong to `account`
/// (Phase 8 §8.12 step 9, `/account/locations`) and aren't offered here yet
/// — this sheet surfaces "Use current location", recents (from `location`'s
/// own repository), and "Search a new area" (the full `/location-setup`
/// flow), which together satisfy §5b.6's "never an empty sheet" empty-state
/// rule on their own.
class LocationSwitcherSheet extends ConsumerStatefulWidget {
  const LocationSwitcherSheet({super.key});

  @override
  ConsumerState<LocationSwitcherSheet> createState() =>
      _LocationSwitcherSheetState();
}

class _LocationSwitcherSheetState extends ConsumerState<LocationSwitcherSheet> {
  List<ResolvedLocation> _recents = const [];
  ResolvedLocation? _current;
  bool _detecting = false;
  String? _detectError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(locationRepositoryProvider);
    final recents = await repo.recentLocations();
    final current = await repo.cachedLocation();
    if (mounted)
      setState(() {
        _recents = recents;
        _current = current;
      });
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _detecting = true;
      _detectError = null;
    });
    try {
      final capability = ref.read(locationCapabilityProvider);
      final repo = ref.read(locationRepositoryProvider);
      final permission = await capability.checkPermission();
      final precision =
          permission == LocationPermissionOutcome.grantedApproximate
          ? LocationPrecision.approximate
          : LocationPrecision.precise;
      final latLng = await capability.getCurrentPosition(
        timeout: const Duration(seconds: 15),
      );
      final resolved = await repo.reverseGeocode(
        latLng,
        precision: precision,
        source: LocationSource.gps,
      );
      await _confirm(resolved);
    } on Object {
      if (mounted) {
        setState(() {
          _detecting = false;
          _detectError = AppLocalizations.of(context).locationSetupGpsFailed;
        });
      }
    }
  }

  Future<void> _confirm(ResolvedLocation location) async {
    await ref.read(locationRepositoryProvider).confirmLocation(location);
    ref.read(sessionStateProvider).markLocationResolved();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Space.x4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.locationSwitcherTitle, style: context.type.title),
            const SizedBox(height: Space.x4),
            AppButton(
              label: l10n.locationSetupUseCurrentLocation,
              variant: AppButtonVariant.secondary,
              icon: Icons.my_location,
              isLoading: _detecting,
              onPressed: _detecting ? null : _useCurrentLocation,
            ),
            if (_detectError != null) ...[
              const SizedBox(height: Space.x2),
              Text(
                _detectError!,
                style: context.type.caption.copyWith(color: colors.critical.fg),
              ),
            ],
            const SizedBox(height: Space.x4),
            if (_recents.isNotEmpty) ...[
              Text(
                l10n.locationSetupRecentSectionTitle,
                style: context.type.label.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              for (final recent in _recents)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.place_outlined),
                  title: Text(recent.displayLabel),
                  trailing: _current?.locality == recent.locality
                      ? Text(
                          l10n.locationSwitcherCurrentBadge,
                          style: context.type.caption.copyWith(
                            color: colors.textTertiary,
                          ),
                        )
                      : null,
                  onTap: () => _confirm(recent),
                ),
            ],
            const SizedBox(height: Space.x2),
            AppButton(
              label: l10n.locationSwitcherSearchNewArea,
              variant: AppButtonVariant.tertiary,
              onPressed: () {
                Navigator.of(context).pop(false);
                context.go('/location-setup');
              },
            ),
          ],
        ),
      ),
    );
  }
}
