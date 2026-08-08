import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:surplus_marketplace/app/router/routes.dart';
import 'package:surplus_marketplace/app/session/session_providers.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/domain/lat_lng.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/core/utils/formatters.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/components/bag_card.dart';
import 'package:surplus_marketplace/design_system/components/legal_disclosure_block.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/bag_summary.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/merchant.dart';
import 'package:surplus_marketplace/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:surplus_marketplace/features/catalog/presentation/screens/reviews_list_screen.dart';
import 'package:surplus_marketplace/features/catalog/presentation/utils/dietary_label.dart';
import 'package:surplus_marketplace/features/config/presentation/providers/config_providers.dart';
import 'package:surplus_marketplace/features/location/presentation/providers/location_providers.dart';

enum _Phase { loading, loaded, notFound, error }

/// §4.2 `/discover/merchant/:merchantId`, §5b.8.
class MerchantProfileScreen extends ConsumerStatefulWidget {
  const MerchantProfileScreen({required this.merchantId, super.key});

  final String merchantId;

  @override
  ConsumerState<MerchantProfileScreen> createState() =>
      _MerchantProfileScreenState();
}

class _MerchantProfileScreenState extends ConsumerState<MerchantProfileScreen> {
  _Phase _phase = _Phase.loading;
  Merchant? _merchant;
  List<BagSummary> _bags = const [];
  int _distanceMetres = 0;
  bool _saved = false;
  bool _watched = false;
  int _photoIndex = 0;
  final _photoController = PageController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _photoController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _phase = _Phase.loading);
    try {
      final repo = ref.read(catalogRepositoryProvider);
      final merchant = await repo.merchant(widget.merchantId);
      final cached = await ref
          .read(locationRepositoryProvider)
          .cachedLocation();
      final anchor =
          cached?.latLng ?? const LatLng(latitude: 12.9716, longitude: 77.5946);
      final bags = await repo.merchantBags(widget.merchantId, anchor);
      final saved = await repo.isMerchantSaved(widget.merchantId);
      final watched = await repo.isMerchantWatched(widget.merchantId);
      if (!mounted) return;
      setState(() {
        _merchant = merchant;
        _bags = bags;
        _distanceMetres = anchor
            .distanceInMetersTo(merchant.address.geo)
            .round();
        _saved = saved;
        _watched = watched;
        _phase = _Phase.loaded;
      });
    } on Object {
      if (mounted) setState(() => _phase = _Phase.notFound);
    }
  }

  Future<void> _toggleSaved() async {
    final session = ref.read(sessionStateProvider);
    if (!session.isAuthenticated) {
      PhoneEntryRoute(
        redirectTo: '/discover/merchant/${widget.merchantId}',
      ).go(context);
      return;
    }
    final next = !_saved;
    setState(() => _saved = next); // optimistic (§2.5)
    try {
      await ref
          .read(catalogRepositoryProvider)
          .setMerchantSaved(widget.merchantId, saved: next);
    } on Object {
      if (mounted) setState(() => _saved = !next); // rollback
    }
  }

  Future<void> _toggleWatched() async {
    final session = ref.read(sessionStateProvider);
    if (!session.isAuthenticated) {
      PhoneEntryRoute(
        redirectTo: '/discover/merchant/${widget.merchantId}',
      ).go(context);
      return;
    }
    final next = !_watched;
    setState(() => _watched = next);
    try {
      await ref
          .read(catalogRepositoryProvider)
          .setMerchantWatched(widget.merchantId, watched: next);
    } on Object {
      if (mounted) setState(() => _watched = !next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    if (_phase == _Phase.loading) {
      return Scaffold(
        backgroundColor: colors.surfaceBase,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_phase == _Phase.notFound || _phase == _Phase.error) {
      return Scaffold(
        backgroundColor: colors.surfaceBase,
        appBar: AppBar(backgroundColor: colors.surfaceBase, elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.x6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.notFoundTitle, style: context.type.title),
                const SizedBox(height: Space.x2),
                Text(
                  l10n.notFoundBody,
                  style: context.type.body.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final merchant = _merchant!;
    final taxonomy = ref.watch(taxonomyProvider);

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      body: SafeArea(
        child: ListView(
          children: [
            _PhotoCarousel(
              photos: merchant.storefrontPhotos,
              index: _photoIndex,
              controller: _photoController,
              onChanged: (i) => setState(() => _photoIndex = i),
              l10n: l10n,
            ),
            Padding(
              padding: const EdgeInsets.all(Space.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(merchant.displayName, style: context.type.display),
                  const SizedBox(height: Space.x1),
                  taxonomy.when(
                    data: (t) {
                      final tag = t.categories
                          .where((c) => c.id == merchant.category)
                          .toList();
                      return Text(
                        tag.isEmpty ? merchant.category : tag.first.label,
                        style: context.type.body.copyWith(
                          color: colors.textSecondary,
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: Space.x2),
                  if (merchant.ratingAggregate.hasReviews)
                    Semantics(
                      label: l10n.merchantRatingSemantic(
                        merchant.ratingAggregate.average.toStringAsFixed(1),
                        merchant.ratingAggregate.count,
                      ),
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => ReviewsListScreen(
                              merchantId: merchant.id,
                              merchantName: merchant.displayName,
                              ratingAverage: merchant.ratingAggregate.average,
                              ratingCount: merchant.ratingAggregate.count,
                              histogram: merchant.ratingAggregate.histogram,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: 16,
                              color: colors.success.fg,
                            ),
                            const SizedBox(width: Space.x1),
                            Text(
                              '${merchant.ratingAggregate.average.toStringAsFixed(1)} '
                              '(${merchant.ratingAggregate.count})',
                              style: context.type.body,
                            ),
                            const SizedBox(width: Space.x2),
                            Text(
                              l10n.merchantSeeAllReviews(
                                merchant.ratingAggregate.count,
                              ),
                              style: context.type.caption.copyWith(
                                color: colors.actionSecondaryFg,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: Space.x4),
                  _TrustBlock(merchant: merchant, l10n: l10n),
                  const SizedBox(height: Space.x4),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: _saved
                              ? l10n.merchantSavedCta
                              : l10n.merchantSaveCta,
                          variant: _saved
                              ? AppButtonVariant.primary
                              : AppButtonVariant.secondary,
                          icon: _saved ? Icons.bookmark : Icons.bookmark_border,
                          onPressed: _toggleSaved,
                        ),
                      ),
                      const SizedBox(width: Space.x2),
                      Expanded(
                        child: AppButton(
                          label: _watched
                              ? l10n.merchantWatchingCta
                              : l10n.bagWatchShop,
                          variant: _watched
                              ? AppButtonVariant.primary
                              : AppButtonVariant.secondary,
                          icon: _watched
                              ? Icons.notifications_active
                              : Icons.notifications_none,
                          onPressed: _toggleWatched,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.x6),
                  Text(
                    merchant.address.displayLine,
                    style: context.type.body,
                  ),
                  const SizedBox(height: Space.x1),
                  Text(
                    '${Fmt.distance(_distanceMetres)} away',
                    style: context.type.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: Space.x2),
                  AppButton(
                    label: l10n.pickupDirections(merchant.displayName),
                    variant: AppButtonVariant.tertiary,
                    icon: Icons.directions_outlined,
                    expand: false,
                    onPressed: () {},
                  ),
                  const SizedBox(height: Space.x6),
                  Text(merchant.operatingHours, style: context.type.body),
                  const SizedBox(height: Space.x2),
                  Text(
                    merchant.description,
                    style: context.type.body.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: Space.x6),
                  if (_bags.isEmpty)
                    _NoBagsEmptyState(
                      merchant: merchant,
                      watched: _watched,
                      onWatch: _toggleWatched,
                      l10n: l10n,
                    )
                  else
                    for (final bag in _bags) ...[
                      BagCard(
                        bag: bag,
                        dietaryLabel: dietaryEnvelopeLabel(
                          bag.dietaryEnvelope,
                          l10n,
                        ),
                        clock: const SystemClock(),
                        onTap: () =>
                            DiscoverBagRoute(bagId: bag.id).push<void>(context),
                      ),
                      const SizedBox(height: Space.listGap),
                    ],
                  const SizedBox(height: Space.x8),
                  LegalDisclosureBlock(
                    legalName: merchant.legalName,
                    fssaiLine:
                        '${l10n.merchantFssaiLabel}: ${merchant.fssaiLicenceNumber}',
                    fssaiValidUntilLine: l10n.merchantFssaiValidUntil(
                      Fmt.expectedBy(merchant.fssaiLicenceExpiry),
                    ),
                    grievanceLine:
                        '${l10n.merchantGrievanceLabel}: ${merchant.grievanceContact}',
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

class _TrustBlock extends StatelessWidget {
  const _TrustBlock({required this.merchant, required this.l10n});

  final Merchant merchant;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasTrustSignal =
        merchant.isVerified || merchant.certifications.contains('halal');
    if (!hasTrustSignal) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.x3),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (merchant.isVerified) ...[
                Icon(Icons.verified, size: 16, color: colors.success.fg),
                const SizedBox(width: Space.x1),
                Text(
                  l10n.merchantVerifiedBadge,
                  style: context.type.caption.copyWith(
                    color: colors.success.fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: Space.x3),
              ],
              if (merchant.certifications.contains('halal'))
                Text(
                  l10n.merchantHalalCertified,
                  style: context.type.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoBagsEmptyState extends StatelessWidget {
  const _NoBagsEmptyState({
    required this.merchant,
    required this.watched,
    required this.onWatch,
    required this.l10n,
  });

  final Merchant merchant;
  final bool watched;
  final VoidCallback onWatch;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.x6),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        children: [
          Text(l10n.merchantNoBagsTitle, style: context.type.title),
          if (merchant.typicalListingTime != null) ...[
            const SizedBox(height: Space.x2),
            Text(
              l10n.merchantNoBagsBody(
                merchant.displayName,
                merchant.typicalListingTime!,
              ),
              style: context.type.body.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: Space.x4),
          AppButton(
            label: watched ? l10n.merchantWatchingCta : l10n.bagWatchShop,
            variant: watched
                ? AppButtonVariant.primary
                : AppButtonVariant.secondary,
            onPressed: onWatch,
          ),
        ],
      ),
    );
  }
}

class _PhotoCarousel extends StatelessWidget {
  const _PhotoCarousel({
    required this.photos,
    required this.index,
    required this.controller,
    required this.onChanged,
    required this.l10n,
  });

  final List<String> photos;
  final int index;
  final PageController controller;
  final ValueChanged<int> onChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (photos.isEmpty) {
      return Container(height: 220, color: colors.surfaceSunken);
    }
    return Semantics(
      label: l10n.merchantPhotoSemantic(index + 1, photos.length),
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            ExcludeSemantics(
              child: PageView(
                controller: controller,
                onPageChanged: onChanged,
                children: [
                  for (final photo in photos)
                    CachedNetworkImage(
                      imageUrl: photo,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) =>
                          Container(color: colors.surfaceSunken),
                      errorWidget: (context, url, error) =>
                          Container(color: colors.surfaceSunken),
                    ),
                ],
              ),
            ),
            if (photos.length > 1) ...[
              Positioned(
                left: Space.x2,
                top: 90,
                child: _CarouselArrow(
                  icon: Icons.chevron_left,
                  onTap: index > 0
                      ? () => controller.previousPage(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                        )
                      : null,
                ),
              ),
              Positioned(
                right: Space.x2,
                top: 90,
                child: _CarouselArrow(
                  icon: Icons.chevron_right,
                  onTap: index < photos.length - 1
                      ? () => controller.nextPage(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                        )
                      : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CarouselArrow extends StatelessWidget {
  const _CarouselArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black45,
    shape: const CircleBorder(),
    child: IconButton(
      icon: Icon(icon, color: Colors.white),
      onPressed: onTap,
    ),
  );
}
