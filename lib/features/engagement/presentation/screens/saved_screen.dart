import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:surplus_marketplace/app/router/routes.dart';
import 'package:surplus_marketplace/app/session/session_providers.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/domain/lat_lng.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/components/availability_state_badge.dart';
import 'package:surplus_marketplace/design_system/components/saved_merchant_card.dart';
import 'package:surplus_marketplace/design_system/components/undo_snackbar.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/catalog/catalog.dart';
import 'package:surplus_marketplace/features/location/location.dart';

enum _Phase { loading, loaded, error }

class _SavedEntry {
  _SavedEntry({
    required this.merchant,
    required this.watching,
    required this.liveBagCount,
  });

  final Merchant merchant;
  bool watching;
  int liveBagCount;
}

const _bengaluruCentre = LatLng(latitude: 12.9716, longitude: 77.5946);

/// §4.2 `/saved`, §5e.2. The retention loop — one list, watch as a
/// per-item bell toggle (**amendment A17**).
class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  _Phase _phase = _Phase.loading;
  List<_SavedEntry> _entries = [];
  bool _liveOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _phase = _Phase.loading);
    try {
      final catalog = ref.read(catalogRepositoryProvider);
      final cached = await ref
          .read(locationRepositoryProvider)
          .cachedLocation();
      final anchor = cached?.latLng ?? _bengaluruCentre;
      final merchants = await catalog.savedMerchants();

      final entries = <_SavedEntry>[];
      for (final merchant in merchants) {
        final bags = await catalog.merchantBags(merchant.id, anchor);
        final watching = await catalog.isMerchantWatched(merchant.id);
        entries.add(
          _SavedEntry(
            merchant: merchant,
            watching: watching,
            // `merchantBags` already filters to `BagStatus.live` (A8) — the
            // returned length is the live count directly.
            liveBagCount: bags.length,
          ),
        );
      }
      entries.sort((a, b) {
        final byAvailability = (b.liveBagCount > 0 ? 1 : 0).compareTo(
          a.liveBagCount > 0 ? 1 : 0,
        );
        if (byAvailability != 0) return byAvailability;
        return anchor
            .distanceInMetersTo(a.merchant.address.geo)
            .compareTo(anchor.distanceInMetersTo(b.merchant.address.geo));
      });

      if (!mounted) return;
      setState(() {
        _entries = entries;
        _phase = _Phase.loaded;
      });
    } on Object {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  Future<void> _toggleWatch(_SavedEntry entry) async {
    // Watching (unlike saving) requires auth — same inline gate as the
    // merchant profile screen's own toggle (Phase 8 §8.12 step 5), since
    // it's what drives push targeting to a specific account.
    if (!ref.read(sessionStateProvider).isAuthenticated) {
      PhoneEntryRoute(redirectTo: '/saved').go(context);
      return;
    }
    final next = !entry.watching;
    setState(() => entry.watching = next);
    try {
      await ref
          .read(catalogRepositoryProvider)
          .setMerchantWatched(entry.merchant.id, watched: next);
    } on Object {
      if (mounted) setState(() => entry.watching = !next);
    }
  }

  Future<void> _unsave(_SavedEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final wasWatching = entry.watching;
    setState(() => _entries = _entries.where((e) => e != entry).toList());
    try {
      await ref
          .read(catalogRepositoryProvider)
          .setMerchantSaved(entry.merchant.id, saved: false);
    } on Object {
      // Best-effort — the optimistic removal already reflects the intent;
      // a failed unsave is recovered the same way as a successful one
      // would be undone, below.
    }
    if (!mounted) return;
    showUndoSnackbar(
      context,
      message: l10n.savedUnsaveUndoMessage(entry.merchant.displayName),
      undoLabel: l10n.undo,
      onUndo: () async {
        final catalog = ref.read(catalogRepositoryProvider);
        await catalog.setMerchantSaved(entry.merchant.id, saved: true);
        if (wasWatching) {
          await catalog.setMerchantWatched(entry.merchant.id, watched: true);
        }
        if (mounted) setState(() => _entries = [..._entries, entry]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final visible = _liveOnly
        ? _entries.where((e) => e.liveBagCount > 0).toList()
        : _entries;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        elevation: 0,
        title: Text(l10n.savedTitle),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.loading => const Center(child: CircularProgressIndicator()),
          _Phase.error => _ErrorState(onRetry: _load, l10n: l10n),
          _Phase.loaded =>
            _entries.isEmpty
                ? _Empty(l10n: l10n)
                : Column(
                    children: [
                      SwitchListTile(
                        value: _liveOnly,
                        onChanged: (v) => setState(() => _liveOnly = v),
                        title: Text(l10n.savedFilterLiveOnly),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.all(Space.x4),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: Space.listGap),
                          itemBuilder: (context, i) {
                            final entry = visible[i];
                            final (kind, label) = _availability(entry, l10n);
                            return SavedMerchantCard(
                              logoUrl: entry.merchant.logoUrl,
                              name: entry.merchant.displayName,
                              subtitle: entry.merchant.category,
                              availabilityKind: kind,
                              availabilityLabel: label,
                              watching: entry.watching,
                              watchSemanticLabel: entry.watching
                                  ? l10n.savedWatchOnSemantic(
                                      entry.merchant.displayName,
                                    )
                                  : l10n.savedWatchOffSemantic(
                                      entry.merchant.displayName,
                                    ),
                              onTap: () => SavedMerchantRoute(
                                merchantId: entry.merchant.id,
                              ).push<void>(context),
                              onToggleWatch: () => _toggleWatch(entry),
                              onUnsave: () => _unsave(entry),
                              unsaveLabel: l10n.savedUnsave,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
        },
      ),
    );
  }

  (AvailabilityKind, String) _availability(
    _SavedEntry entry,
    AppLocalizations l10n,
  ) {
    if (entry.liveBagCount > 0) {
      return (
        AvailabilityKind.availableNow,
        l10n.availabilityAvailableNow(entry.liveBagCount),
      );
    }
    final hint = entry.merchant.typicalListingTime;
    if (hint != null) {
      return (
        AvailabilityKind.expectedLater,
        l10n.availabilityExpectedLater(hint),
      );
    }
    return (AvailabilityKind.closedToday, l10n.availabilityClosedToday);
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
            Icon(Icons.bookmark_border, size: 64, color: colors.textTertiary),
            const SizedBox(height: Space.x4),
            Text(
              l10n.savedEmptyTitle,
              style: context.type.display,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.x2),
            Text(
              l10n.savedEmptyBody,
              style: context.type.body.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.x6),
            AppButton(
              label: l10n.ordersDiscoverCta,
              onPressed: () => const DiscoverRoute().go(context),
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
