import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:surplus_marketplace/app/router/routes.dart';
import 'package:surplus_marketplace/app/theme/app_colors.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/domain/dietary_envelope.dart';
import 'package:surplus_marketplace/core/domain/lat_lng.dart';
import 'package:surplus_marketplace/core/domain/pickup_window.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/core/platform/location_capability.dart';
import 'package:surplus_marketplace/core/platform/map_tile_config_provider.dart';
import 'package:surplus_marketplace/core/utils/formatters.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/components/bag_card.dart';
import 'package:surplus_marketplace/design_system/components/tile_map_view.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/bag_summary.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/coverage_status.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/discover_query.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/discover_sort.dart';
import 'package:surplus_marketplace/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:surplus_marketplace/features/catalog/presentation/sheets/filter_sheet.dart';
import 'package:surplus_marketplace/features/catalog/presentation/sheets/location_switcher_sheet.dart';
import 'package:surplus_marketplace/features/catalog/presentation/sheets/sort_sheet.dart';
import 'package:surplus_marketplace/features/catalog/presentation/utils/dietary_label.dart';
import 'package:surplus_marketplace/features/location/presentation/providers/location_providers.dart';
import 'package:surplus_marketplace/features/onboarding/presentation/providers/onboarding_providers.dart';

enum _Phase { loading, loaded, error }

enum _ViewMode { list, map }

/// The primary surface of the product (§4.2 `/discover`, §5b.1).
///
/// **Map view (§5b.2)** now renders real MapTiler tiles (`TileMapView`,
/// §8.6's `MapTileConfig`) with a pin per bag. List stays the default view
/// (D-b3) and the complete functional equivalent — the map is additive,
/// same "never load-bearing for the accessibility floor" reasoning as
/// `location`'s pin-drop picker.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  static const _clock = SystemClock();
  static const _fallbackAnchor = LatLng(latitude: 12.9716, longitude: 77.5946);

  _Phase _phase = _Phase.loading;
  _ViewMode _viewMode = _ViewMode.list;
  DiscoverQuery? _query;
  List<BagSummary> _items = const [];
  CoverageStatus? _coverage;
  String _localityLabel = '';
  bool _notifySubmitting = false;
  bool _notifyRegistered = false;

  final _mapController = fm.MapController();
  bool _isLocatingGps = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    _mapController.move(
      camera.center,
      (camera.zoom + delta).clamp(camera.minZoom ?? 1, camera.maxZoom ?? 18),
    );
  }

  Future<void> _recenterOnMe() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isLocatingGps = true);
    try {
      final capability = ref.read(locationCapabilityProvider);
      final permission = await capability.checkPermission();
      if (permission == LocationPermissionOutcome.denied) {
        await capability.requestPermission();
      }
      final latLng = await capability.getCurrentPosition(
        timeout: const Duration(seconds: 15),
      );
      if (!mounted) return;
      _mapController.move(
        ll.LatLng(latLng.latitude, latLng.longitude),
        _mapController.camera.zoom,
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.discoverMapRecenterFailed)));
      }
    } finally {
      if (mounted) setState(() => _isLocatingGps = false);
    }
  }

  Future<void> _load() async {
    setState(() => _phase = _Phase.loading);
    try {
      final cached = await ref
          .read(locationRepositoryProvider)
          .cachedLocation();
      final anchor = cached?.latLng ?? _fallbackAnchor;
      final preference = await ref
          .read(onboardingRepositoryProvider)
          .dietaryPreference();
      final query = DiscoverQuery(
        anchor: anchor,
        acceptedEnvelopes:
            (preference ?? DietaryPreference.everything).acceptedEnvelopes,
      );
      if (mounted)
        setState(() => _localityLabel = cached?.locality ?? 'your area');
      await _runQuery(query);
    } on Object {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  Future<void> _runQuery(DiscoverQuery query) async {
    setState(() => _phase = _Phase.loading);
    try {
      final repo = ref.read(catalogRepositoryProvider);
      final page = await repo.discoverBags(query);
      CoverageStatus? coverage;
      if (page.items.isEmpty) coverage = await repo.coverage(query.anchor);
      if (!mounted) return;
      setState(() {
        _query = query;
        _items = page.items;
        _coverage = coverage;
        _phase = _Phase.loaded;
        _notifyRegistered = false;
      });
    } on Object {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  Future<void> _openFilterSheet() async {
    final current = _query;
    if (current == null) return;
    final result = await showModalBottomSheet<DiscoverQuery>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FilterSheet(initial: current),
    );
    if (result != null) await _runQuery(result);
  }

  Future<void> _openSortSheet() async {
    final current = _query;
    if (current == null) return;
    final result = await showModalBottomSheet<DiscoverQuery>(
      context: context,
      builder: (context) => SortSheet(initial: current),
    );
    if (result != null) await _runQuery(result);
  }

  Future<void> _openLocationSwitcher() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const LocationSwitcherSheet(),
    );
    if (changed == true) await _load();
  }

  void _toggleViewMode() => setState(
    () => _viewMode = _viewMode == _ViewMode.list
        ? _ViewMode.map
        : _ViewMode.list,
  );

  Future<void> _notifyCoverage(LatLng anchor) async {
    setState(() => _notifySubmitting = true);
    try {
      await ref
          .read(catalogRepositoryProvider)
          .notifyCoverage(locality: _localityLabel, anchor: anchor);
      if (mounted) {
        setState(() {
          _notifySubmitting = false;
          _notifyRegistered = true;
        });
      }
    } on Object {
      if (mounted) setState(() => _notifySubmitting = false);
    }
  }

  Future<void> _clearFilters() async {
    final current = _query;
    if (current == null) return;
    await _runQuery(
      DiscoverQuery(
        anchor: current.anchor,
        acceptedEnvelopes: current.acceptedEnvelopes,
      ),
    );
  }

  ({
    List<BagSummary> collectNow,
    List<BagSummary> laterToday,
    List<BagSummary> tomorrow,
  })
  _bucketed() {
    final now = _clock.now();
    final collectNow = <BagSummary>[];
    final laterToday = <BagSummary>[];
    final tomorrow = <BagSummary>[];
    for (final item in _items) {
      final urgency = item.pickupWindow.urgencyAt(_clock);
      final startsToday =
          item.pickupWindow.startAt.year == now.year &&
          item.pickupWindow.startAt.month == now.month &&
          item.pickupWindow.startAt.day == now.day;
      if (urgency == WindowUrgency.openNow ||
          urgency == WindowUrgency.closingSoon) {
        collectNow.add(item);
      } else if (startsToday) {
        laterToday.add(item);
      } else {
        tomorrow.add(item);
      }
    }
    return (collectNow: collectNow, laterToday: laterToday, tomorrow: tomorrow);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final query = _query;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        elevation: 0,
        title: InkWell(
          onTap: _openLocationSwitcher,
          borderRadius: BorderRadius.circular(Radii.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.x2,
              vertical: Space.x1,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: Space.x1),
                Flexible(
                  child: Text(
                    _localityLabel,
                    style: context.type.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.expand_more, size: 18, color: colors.textSecondary),
              ],
            ),
          ),
        ),
        actions: [
          // Notifications aren't built yet (`engagement`, Phase 8 §8.12 step
          // 8) — left as a non-interactive icon rather than inventing
          // unspecced "coming soon" copy for a single affordance.
          const IconButton(
            icon: Icon(Icons.notifications_none),
            onPressed: null,
          ),
          const SizedBox(width: Space.x2),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.x4,
                0,
                Space.x4,
                Space.x2,
              ),
              child: _SearchBarButton(
                hint: l10n.discoverSearchHint,
                onTap: () => const DiscoverSearchRoute().push<void>(context),
              ),
            ),
            if (query != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.x4,
                  vertical: Space.x2,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FacetBarButton(
                              label: query.hasActiveFacets
                                  ? l10n.filterSheetTitle
                                  : l10n.filterSheetTitle,
                              active: query.hasActiveFacets,
                              icon: Icons.tune,
                              onTap: _openFilterSheet,
                            ),
                            const SizedBox(width: Space.x2),
                            _FacetBarButton(
                              label: l10n.sortSheetTitle,
                              active:
                                  query.sort !=
                                  DiscoverSort.urgencyThenDistance,
                              icon: Icons.swap_vert,
                              onTap: _openSortSheet,
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _viewMode == _ViewMode.list
                            ? Icons.map_outlined
                            : Icons.list,
                      ),
                      tooltip: _viewMode == _ViewMode.list
                          ? l10n.discoverMapViewCta
                          : l10n.discoverListViewCta,
                      onPressed: _toggleViewMode,
                    ),
                  ],
                ),
              ),
            Expanded(child: _buildBody(context, l10n)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    switch (_phase) {
      case _Phase.loading:
        return const Center(child: CircularProgressIndicator());
      case _Phase.error:
        return _ErrorState(onRetry: _load, l10n: l10n);
      case _Phase.loaded:
        // Map mode always renders a real map, even with zero pins — falling
        // through to the list's text empty-state here would make the map
        // toggle a silent no-op exactly when there's nothing to list
        // (e.g. an over-filtered or genuinely bag-less area), which reads
        // as "the map is broken" rather than "there's nothing to show yet".
        if (_viewMode == _ViewMode.map) return _buildMap(context, l10n);
        if (_items.isEmpty) return _buildEmptyState(context, l10n);
        return _buildSections(context, l10n);
    }
  }

  Widget _buildMap(BuildContext context, AppLocalizations l10n) {
    final colors = context.colors;
    final anchor = _query!.anchor;
    final map = TileMapView(
      tileConfig: ref.watch(mapTileConfigProvider),
      center: anchor,
      zoom: 13,
      mapController: _mapController,
      pins: [
        for (final bag in _items)
          MapPin(
            position: bag.geo,
            onTap: () => DiscoverBagRoute(bagId: bag.id).push<void>(context),
            child: Tooltip(
              message: l10n.discoverMapPinSemantic(
                bag.title,
                bag.merchant.displayName,
              ),
              child: Icon(
                Icons.storefront,
                size: 32,
                color: context.colors.actionPrimaryBg,
              ),
            ),
          ),
      ],
    );
    return Stack(
      children: [
        map,
        if (_items.isEmpty)
          Positioned(
            left: Space.x4,
            right: Space.x4,
            top: Space.x4,
            child: Material(
              color: colors.surfaceRaised,
              borderRadius: BorderRadius.circular(Radii.chip),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.x4,
                  vertical: Space.x3,
                ),
                child: Text(
                  l10n.discoverMapNoBags,
                  textAlign: TextAlign.center,
                  style: context.type.body.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          right: Space.x4,
          bottom: Space.x4,
          child: _MapControls(
            isLocatingGps: _isLocatingGps,
            onZoomIn: () => _zoomBy(1),
            onZoomOut: () => _zoomBy(-1),
            onRecenter: _recenterOnMe,
            l10n: l10n,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    final coverage = _coverage;
    final anchor = _query!.anchor;
    return switch (coverage) {
      CoverageNoCoverage(
        :final nearestLiveAreaName,
        :final nearestLiveAreaDistanceMetres,
      ) =>
        _NoCoverageState(
          locality: _localityLabel,
          nearestAreaName: nearestLiveAreaName,
          nearestAreaDistanceMetres: nearestLiveAreaDistanceMetres,
          submitting: _notifySubmitting,
          registered: _notifyRegistered,
          onNotify: () => _notifyCoverage(anchor),
          l10n: l10n,
        ),
      CoverageNoSupplyNow(:final typicalWindowStart) => _NoSupplyNowState(
        locality: _localityLabel,
        typicalWindowStart: typicalWindowStart,
        submitting: _notifySubmitting,
        registered: _notifyRegistered,
        onNotify: () => _notifyCoverage(anchor),
        l10n: l10n,
      ),
      _ => _OverFilteredState(onClear: _clearFilters, l10n: l10n),
    };
  }

  Widget _buildSections(BuildContext context, AppLocalizations l10n) {
    final buckets = _bucketed();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x4,
          vertical: Space.x2,
        ),
        children: [
          if (buckets.collectNow.isNotEmpty)
            _BagSection(
              title: l10n.discoverSectionCollectNow,
              bags: buckets.collectNow,
              l10n: l10n,
            ),
          if (buckets.laterToday.isNotEmpty)
            _BagSection(
              title: l10n.discoverSectionLaterToday,
              bags: buckets.laterToday,
              l10n: l10n,
            ),
          if (buckets.tomorrow.isNotEmpty)
            _BagSection(
              title: l10n.discoverSectionTomorrow,
              bags: buckets.tomorrow,
              l10n: l10n,
            ),
          const SizedBox(height: Space.x6),
        ],
      ),
    );
  }
}

/// Zoom +/− and "recentre on me", stacked bottom-right over the map —
/// flutter_map ships neither, and pinch/scroll-wheel-only zoom isn't
/// discoverable on desktop web without a mouse wheel or trackpad gesture.
class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.isLocatingGps,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRecenter,
    required this.l10n,
  });

  final bool isLocatingGps;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRecenter;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MapControlButton(
          icon: Icons.my_location,
          tooltip: l10n.discoverMapRecenter,
          onPressed: isLocatingGps ? null : onRecenter,
          loading: isLocatingGps,
        ),
        const SizedBox(height: Space.x3),
        Material(
          color: context.colors.surfaceRaised,
          borderRadius: BorderRadius.circular(Radii.chip),
          elevation: 2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapControlButton(
                icon: Icons.add,
                tooltip: l10n.discoverMapZoomIn,
                onPressed: onZoomIn,
                flat: true,
              ),
              Divider(height: 1, color: context.colors.borderSubtle),
              _MapControlButton(
                icon: Icons.remove,
                tooltip: l10n.discoverMapZoomOut,
                onPressed: onZoomOut,
                flat: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.loading = false,
    this.flat = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool loading;

  /// Flat buttons skip their own Material/elevation — used when a parent
  /// (the zoom +/− pair) already provides one shared surface.
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final button = InkWell(
      onTap: onPressed,
      child: SizedBox(
        width: Layout.minTouchTarget,
        height: Layout.minTouchTarget,
        child: Center(
          child: loading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.textSecondary,
                  ),
                )
              : Icon(icon, color: colors.textPrimary),
        ),
      ),
    );
    return Tooltip(
      message: tooltip,
      child: flat
          ? button
          : Material(
              color: colors.surfaceRaised,
              borderRadius: BorderRadius.circular(Radii.chip),
              elevation: 2,
              child: button,
            ),
    );
  }
}

/// The pill search bar pinned to the top of Discover — visually a search
/// field, functionally a button that opens [DiscoverSearchRoute]. Typing
/// happens on that screen, not here, so a real `TextField` (with its own
/// focus/keyboard handling) would be misleading.
class _SearchBarButton extends StatelessWidget {
  const _SearchBarButton({required this.hint, required this.onTap});

  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surfaceSunken,
      borderRadius: BorderRadius.circular(Radii.full),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.full),
        child: Container(
          constraints: const BoxConstraints(minHeight: Layout.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: Space.x4),
          child: Row(
            children: [
              Icon(Icons.search, color: colors.textSecondary),
              const SizedBox(width: Space.x2),
              Text(
                hint,
                style: context.type.bodyLarge.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FacetBarButton extends StatelessWidget {
  const _FacetBarButton({
    required this.label,
    required this.active,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool active;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = active ? colors.actionSecondaryFg : colors.textSecondary;
    return Material(
      color: active
          ? colors.actionPrimaryBg.withValues(alpha: 0.12)
          : colors.surfaceSunken,
      borderRadius: BorderRadius.circular(Radii.chip),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.chip),
        child: Container(
          constraints: const BoxConstraints(minHeight: Layout.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: Space.x3),
          decoration: BoxDecoration(
            border: Border.all(
              color: active
                  ? colors.actionSecondaryBorder
                  : colors.borderSubtle,
            ),
            borderRadius: BorderRadius.circular(Radii.chip),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: Space.x1),
              Text(
                label,
                style: context.type.caption.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BagSection extends StatelessWidget {
  const _BagSection({
    required this.title,
    required this.bags,
    required this.l10n,
  });

  final String title;
  final List<BagSummary> bags;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.x2),
            child: Text(
              title,
              style: context.type.title.copyWith(color: colors.textPrimary),
            ),
          ),
        ),
        for (final bag in bags) ...[
          BagCard(
            bag: bag,
            dietaryLabel: dietaryEnvelopeLabel(bag.dietaryEnvelope, l10n),
            clock: const SystemClock(),
            onTap: () => DiscoverBagRoute(bagId: bag.id).push<void>(context),
          ),
          const SizedBox(height: Space.listGap),
        ],
        const SizedBox(height: Space.x4),
      ],
    );
  }
}

class _NoCoverageState extends StatelessWidget {
  const _NoCoverageState({
    required this.locality,
    required this.nearestAreaName,
    required this.nearestAreaDistanceMetres,
    required this.submitting,
    required this.registered,
    required this.onNotify,
    required this.l10n,
  });

  final String locality;
  final String nearestAreaName;
  final int nearestAreaDistanceMetres;
  final bool submitting;
  final bool registered;
  final VoidCallback onNotify;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _EmptyStateScaffold(
      icon: Icons.explore_off_outlined,
      title: l10n.noCoverageTitle(locality),
      body: registered
          ? l10n.notifyRegistered
          : '${l10n.noCoverageBody}\n${l10n.noCoverageNearest(nearestAreaName, Fmt.distance(nearestAreaDistanceMetres))}',
      colors: colors,
      action: registered
          ? null
          : AppButton(
              label: l10n.noCoverageCta(locality),
              isLoading: submitting,
              onPressed: submitting ? null : onNotify,
            ),
    );
  }
}

class _NoSupplyNowState extends StatelessWidget {
  const _NoSupplyNowState({
    required this.locality,
    required this.typicalWindowStart,
    required this.submitting,
    required this.registered,
    required this.onNotify,
    required this.l10n,
  });

  final String locality;
  final String typicalWindowStart;
  final bool submitting;
  final bool registered;
  final VoidCallback onNotify;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _EmptyStateScaffold(
      icon: Icons.schedule_outlined,
      title: l10n.noSupplyNowTitle(locality),
      body: registered
          ? l10n.notifyRegistered
          : l10n.noSupplyNowBody(typicalWindowStart, ''),
      colors: colors,
      action: registered
          ? null
          : AppButton(
              label: l10n.noSupplyNowWatchCta,
              isLoading: submitting,
              onPressed: submitting ? null : onNotify,
            ),
    );
  }
}

class _OverFilteredState extends StatelessWidget {
  const _OverFilteredState({required this.onClear, required this.l10n});

  final VoidCallback onClear;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => _EmptyStateScaffold(
    icon: Icons.filter_alt_off_outlined,
    title: l10n.overFilteredTitle,
    body: null,
    colors: context.colors,
    action: AppButton(label: l10n.overFilteredCta, onPressed: onClear),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry, required this.l10n});

  final Future<void> Function() onRetry;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => _EmptyStateScaffold(
    icon: Icons.error_outline,
    title: l10n.errorServerTitle,
    body: l10n.errorServerBody,
    colors: context.colors,
    action: AppButton(label: l10n.retryCta, onPressed: onRetry),
  );
}

class _EmptyStateScaffold extends StatelessWidget {
  const _EmptyStateScaffold({
    required this.icon,
    required this.title,
    required this.body,
    required this.colors,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String? body;
  final AppColors colors;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(Space.x6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: colors.textTertiary),
          const SizedBox(height: Space.x4),
          Text(
            title,
            style: context.type.display,
            textAlign: TextAlign.center,
          ),
          if (body != null) ...[
            const SizedBox(height: Space.x2),
            Text(
              body!,
              style: context.type.body.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: Space.x6),
            action!,
          ],
        ],
      ),
    ),
  );
}
