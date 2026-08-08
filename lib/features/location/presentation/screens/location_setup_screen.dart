import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:surplus_marketplace/app/session/session_providers.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/domain/lat_lng.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/core/platform/location_capability.dart';
import 'package:surplus_marketplace/core/platform/map_tile_config.dart';
import 'package:surplus_marketplace/core/platform/map_tile_config_provider.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/components/tile_map_view.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/location/domain/entities/locality_suggestion.dart';
import 'package:surplus_marketplace/features/location/domain/entities/location_precision.dart';
import 'package:surplus_marketplace/features/location/domain/entities/location_source.dart';
import 'package:surplus_marketplace/features/location/domain/entities/resolved_location.dart';
import 'package:surplus_marketplace/features/location/presentation/providers/location_providers.dart';

const _bengaluruCentre = LatLng(latitude: 12.9716, longitude: 77.5946);

/// Establishes a discovery anchor by *any* means (§4.2 `/location-setup`,
/// §5a.4). Must be fully functional with location permission permanently
/// denied (§4.9 requirement 2) — every path below except "Use current
/// location" works with no permission at all.
///
/// **Real map, via MapTiler** (`TileMapView`, §8.6's `MapTileConfig`
/// boundary) — the resolved-location card renders an actual tile map
/// thumbnail, and "Drop pin" opens a real interactive centred-pin picker
/// rather than always resolving to the launch city's centre. The
/// search-and-confirm path remains independently sufficient without any
/// map interaction (§4.9 requirement 2's own accessibility floor) — the
/// map is additive, never load-bearing.
class LocationSetupScreen extends ConsumerStatefulWidget {
  const LocationSetupScreen({this.redirectTo, super.key});

  final String? redirectTo;

  @override
  ConsumerState<LocationSetupScreen> createState() =>
      _LocationSetupScreenState();
}

class _LocationSetupScreenState extends ConsumerState<LocationSetupScreen> {
  final _searchController = TextEditingController();

  List<LocalitySuggestion> _recents = [];
  List<LocalitySuggestion> _popular = [];
  List<LocalitySuggestion> _results = [];
  bool _searched = false;

  bool _isDeniedPermanently = false;
  bool _isDetectingGps = false;
  bool _gpsFailed = false;
  bool _isOffline = false;

  ResolvedLocation? _resolved;
  bool? _withinBounds;

  String get _destination => widget.redirectTo ?? '/dietary-setup';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onQueryChanged);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(locationRepositoryProvider);
    final capability = ref.read(locationCapabilityProvider);

    final connectivity = await Connectivity().checkConnectivity();
    final offline = connectivity.every((r) => r == ConnectivityResult.none);

    // §4.9 requirement 2 — this screen must be fully functional with no
    // permission at all, so a platform that cannot even answer the
    // permission question (rather than answering "denied") degrades to the
    // same manual-entry-only state instead of crashing the screen.
    final permission = await capability.checkPermission().catchError(
      (_) => LocationPermissionOutcome.denied,
    );
    final recents = await repo.recentLocations();
    final popular = await repo.popularLocalities();

    if (!mounted) return;
    setState(() {
      _isOffline = offline;
      _isDeniedPermanently =
          permission == LocationPermissionOutcome.deniedPermanently;
      _recents = recents
          .map(
            (r) => LocalitySuggestion(
              id: 'recent_${r.locality}',
              locality: r.locality,
              city: r.city,
              pincode: r.pincode,
              latLng: r.latLng,
            ),
          )
          .toList();
      _popular = popular;
    });

    if (offline) {
      final cached = await repo.cachedLocation();
      if (mounted && cached != null) await _selectResolved(cached);
    }
  }

  Future<void> _onQueryChanged() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searched = false;
        _results = [];
      });
      return;
    }
    final results = await ref.read(locationRepositoryProvider).search(query);
    if (!mounted) return;
    setState(() {
      _searched = true;
      _results = results;
    });
  }

  /// Indian PIN codes begin 1–8 (§5a.4) — a numeric query that looks like an
  /// attempted pincode but violates that is called out explicitly rather
  /// than silently falling through to "no results".
  String? get _pincodeHint {
    final query = _searchController.text.trim();
    if (!RegExp(r'^[0-9]+$').hasMatch(query) || query.length != 6) return null;
    return RegExp(r'^[1-8][0-9]{5}$').hasMatch(query)
        ? null
        : AppLocalizations.of(context).locationSetupPincodeInvalid;
  }

  Future<void> _selectSuggestion(LocalitySuggestion suggestion) async {
    await _selectResolved(
      ResolvedLocation(
        latLng: suggestion.latLng,
        locality: suggestion.locality,
        city: suggestion.city,
        pincode: suggestion.pincode,
        precision: LocationPrecision.precise,
        source: LocationSource.search,
      ),
    );
  }

  Future<void> _selectResolved(ResolvedLocation location) async {
    final withinBounds = await ref
        .read(locationRepositoryProvider)
        .isWithinServiceableBounds(location.latLng);
    if (!mounted) return;
    setState(() {
      _resolved = location;
      _withinBounds = withinBounds;
      _gpsFailed = false;
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isDetectingGps = true;
      _gpsFailed = false;
    });
    try {
      final capability = ref.read(locationCapabilityProvider);
      final permission = await capability.checkPermission();
      final precision =
          permission == LocationPermissionOutcome.grantedApproximate
          ? LocationPrecision.approximate
          : LocationPrecision.precise;
      final latLng = await capability.getCurrentPosition(
        timeout: const Duration(seconds: 15),
      );
      final resolved = await ref
          .read(locationRepositoryProvider)
          .reverseGeocode(
            latLng,
            precision: precision,
            source: LocationSource.gps,
          );
      if (!mounted) return;
      setState(() => _isDetectingGps = false);
      await _selectResolved(resolved);
    } on Object {
      if (!mounted) return;
      setState(() {
        _isDetectingGps = false;
        _gpsFailed = true;
      });
    }
  }

  Future<void> _dropPin() async {
    final tileConfig = ref.read(mapTileConfigProvider);
    final startingPoint = _resolved?.latLng ?? _bengaluruCentre;
    final picked = await showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _PinDropSheet(tileConfig: tileConfig, initialCenter: startingPoint),
    );
    if (picked == null || !mounted) return;

    final capability = ref.read(locationCapabilityProvider);
    final permission = await capability.checkPermission();
    final precision = permission == LocationPermissionOutcome.grantedApproximate
        ? LocationPrecision.approximate
        : LocationPrecision.precise;
    final resolved = await ref
        .read(locationRepositoryProvider)
        .reverseGeocode(
          picked,
          precision: precision,
          source: LocationSource.pin,
        );
    await _selectResolved(resolved);
  }

  Future<void> _confirm() async {
    final resolved = _resolved;
    if (resolved == null || _withinBounds != true) return;
    await ref.read(locationRepositoryProvider).confirmLocation(resolved);
    if (!mounted) return;
    ref.read(sessionStateProvider).markLocationResolved();
    context.go(_destination);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final pincodeHint = _pincodeHint;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        elevation: 0,
        title: Text(l10n.locationSetupTitle, style: context.type.title),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Space.x6),
          children: [
            if (_isOffline) ...[
              _Banner(text: l10n.locationSetupOfflineBanner),
              const SizedBox(height: Space.x4),
            ],
            TextField(
              controller: _searchController,
              keyboardType: TextInputType.streetAddress,
              decoration: InputDecoration(
                labelText: l10n.locationSetupSearchLabel,
                errorText: pincodeHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
              ),
            ),
            const SizedBox(height: Space.x4),
            if (!_isDeniedPermanently)
              AppButton(
                label: l10n.locationSetupUseCurrentLocation,
                variant: AppButtonVariant.secondary,
                icon: Icons.my_location,
                isLoading: _isDetectingGps,
                onPressed: _isDetectingGps ? null : _useCurrentLocation,
              )
            else ...[
              _Banner(text: l10n.locationSetupDeniedPermanentlyNotice),
              const SizedBox(height: Space.x3),
              AppButton(
                label: l10n.locationSetupOpenSettings,
                variant: AppButtonVariant.secondary,
                onPressed: () =>
                    ref.read(locationCapabilityProvider).openAppSettings(),
              ),
            ],
            if (_gpsFailed) ...[
              const SizedBox(height: Space.x3),
              _Banner(text: l10n.locationSetupGpsFailed),
            ],
            const SizedBox(height: Space.x6),
            if (_searched)
              _ResultsSection(
                title: null,
                results: _results,
                noResultsText: l10n.locationSetupNoResults,
                announcement: l10n.locationSetupResultsAnnouncement(
                  _results.length,
                ),
                onSelect: _selectSuggestion,
                trailing: _results.isEmpty
                    ? AppButton(
                        label: l10n.locationSetupDropPin,
                        variant: AppButtonVariant.tertiary,
                        onPressed: _dropPin,
                      )
                    : null,
              )
            else ...[
              if (_recents.isNotEmpty)
                _ResultsSection(
                  title: l10n.locationSetupRecentSectionTitle,
                  results: _recents,
                  noResultsText: null,
                  announcement: null,
                  onSelect: _selectSuggestion,
                ),
              _ResultsSection(
                title: l10n.locationSetupPopularSectionTitle('Bengaluru'),
                results: _popular,
                noResultsText: null,
                announcement: null,
                onSelect: _selectSuggestion,
              ),
            ],
            if (_resolved != null) ...[
              const SizedBox(height: Space.x4),
              _ResolvedCard(
                location: _resolved!,
                withinBounds: _withinBounds,
                tileConfig: ref.watch(mapTileConfigProvider),
              ),
              if (_withinBounds == false) ...[
                const SizedBox(height: Space.x2),
                _Banner(text: l10n.locationSetupOutsideBounds),
              ],
              if (_resolved!.precision == LocationPrecision.approximate) ...[
                const SizedBox(height: Space.x2),
                _Banner(text: l10n.locationSetupApproximateNotice),
              ],
            ],
            const SizedBox(height: Space.x6),
            AppButton(
              label: l10n.locationSetupConfirmCta,
              onPressed: (_resolved != null && _withinBounds == true)
                  ? _confirm
                  : null,
              disabledReason: _withinBounds == false
                  ? l10n.locationSetupOutsideBounds
                  : l10n.locationSetupConfirmDisabledReason,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsSection extends StatelessWidget {
  const _ResultsSection({
    required this.title,
    required this.results,
    required this.noResultsText,
    required this.announcement,
    required this.onSelect,
    this.trailing,
  });

  final String? title;
  final List<LocalitySuggestion> results;
  final String? noResultsText;
  final String? announcement;
  final void Function(LocalitySuggestion) onSelect;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final body = results.isEmpty && noResultsText != null
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  noResultsText!,
                  style: context.type.body.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(height: Space.x3),
                  trailing!,
                ],
              ],
            ),
          )
        : Column(
            children: [
              for (final suggestion in results)
                _SuggestionRow(
                  suggestion: suggestion,
                  onTap: () => onSelect(suggestion),
                ),
            ],
          );

    return Semantics(
      liveRegion: announcement != null,
      label: announcement,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: context.type.label.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: Space.x2),
          ],
          body,
          const SizedBox(height: Space.x2),
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.suggestion, required this.onTap});

  final LocalitySuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: Space.x3,
            horizontal: Space.x2,
          ),
          child: Row(
            children: [
              Icon(Icons.place_outlined, color: colors.textSecondary, size: 20),
              const SizedBox(width: Space.x3),
              Expanded(
                child: Text(suggestion.label, style: context.type.body),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResolvedCard extends StatelessWidget {
  const _ResolvedCard({
    required this.location,
    required this.withinBounds,
    required this.tileConfig,
  });

  final ResolvedLocation location;
  final bool? withinBounds;
  final MapTileConfig tileConfig;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.locationSetupMapSemanticLabel(location.displayLabel),
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: colors.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 140,
              child: IgnorePointer(
                // A thumbnail, not a second interactive picker — "Drop
                // pin" (`_PinDropSheet`) is the one interactive map.
                child: TileMapView(
                  tileConfig: tileConfig,
                  center: location.latLng,
                  zoom: 14,
                  interactive: false,
                  pins: [
                    MapPin(
                      position: location.latLng,
                      child: Icon(
                        Icons.location_pin,
                        size: 36,
                        color: withinBounds == false
                            ? colors.critical.fg
                            : colors.success.fg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Space.x4),
              child: Row(
                children: [
                  Icon(
                    Icons.location_pin,
                    color: withinBounds == false
                        ? colors.critical.fg
                        : colors.success.fg,
                  ),
                  const SizedBox(width: Space.x3),
                  Expanded(
                    child: Text(
                      location.displayLabel,
                      style: context.type.title,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// §5a.4's "Drop pin" — a real centred-pin picker: the map pans underneath
/// a fixed centre icon (the standard "pin follows the map, not your
/// finger" pattern), confirmed explicitly rather than resolving on the
/// first frame.
class _PinDropSheet extends StatefulWidget {
  const _PinDropSheet({required this.tileConfig, required this.initialCenter});

  final MapTileConfig tileConfig;
  final LatLng initialCenter;

  @override
  State<_PinDropSheet> createState() => _PinDropSheetState();
}

class _PinDropSheetState extends State<_PinDropSheet> {
  late LatLng _center = widget.initialCenter;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(Space.x4),
            child: Text(l10n.locationSetupDropPin, style: context.type.title),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                TileMapView(
                  tileConfig: widget.tileConfig,
                  center: widget.initialCenter,
                  zoom: 15,
                  onCenterChanged: (center) => setState(() => _center = center),
                ),
                // Fixed at the visual centre — the map moves under it, not
                // the other way round.
                Padding(
                  padding: const EdgeInsets.only(bottom: 36),
                  child: Icon(
                    Icons.location_pin,
                    size: 44,
                    color: colors.actionPrimaryBg,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Space.x4),
            child: AppButton(
              label: l10n.locationSetupConfirmPinCta,
              onPressed: () => Navigator.of(context).pop(_center),
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.x3),
      decoration: BoxDecoration(
        color: colors.info.bg,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Text(
        text,
        style: context.type.body.copyWith(color: colors.info.fg),
      ),
    );
  }
}
