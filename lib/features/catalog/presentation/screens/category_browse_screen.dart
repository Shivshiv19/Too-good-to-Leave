import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:surplus_marketplace/app/router/routes.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/domain/dietary_envelope.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/design_system/components/bag_card.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/bag_summary.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/discover_query.dart';
import 'package:surplus_marketplace/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:surplus_marketplace/features/catalog/presentation/utils/dietary_label.dart';
import 'package:surplus_marketplace/features/config/presentation/providers/config_providers.dart';
import 'package:surplus_marketplace/features/location/presentation/providers/location_providers.dart';
import 'package:surplus_marketplace/features/onboarding/presentation/providers/onboarding_providers.dart';

enum _Phase { loading, loaded, notFound, error }

/// §4.2 `/discover/category/:categoryId`, §5b.7 — the full §5b.1 facet bar
/// with the category locked, so this reuses [BagCard] rather than a
/// bespoke list.
class CategoryBrowseScreen extends ConsumerStatefulWidget {
  const CategoryBrowseScreen({required this.categoryId, super.key});

  final String categoryId;

  @override
  ConsumerState<CategoryBrowseScreen> createState() =>
      _CategoryBrowseScreenState();
}

class _CategoryBrowseScreenState extends ConsumerState<CategoryBrowseScreen> {
  _Phase _phase = _Phase.loading;
  List<BagSummary> _items = const [];
  String _categoryLabel = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _phase = _Phase.loading);
    try {
      final taxonomy = await ref.read(taxonomyProvider.future);
      final matches = taxonomy.categories.where(
        (t) => t.id == widget.categoryId,
      );
      final tag = matches.isEmpty ? null : matches.first;
      // §5b.7 — a shared link or stale cache can reference a category the
      // current taxonomy no longer has. Resolved against the taxonomy
      // before declaring not-found, per the spec's own validation rule.
      if (tag == null) {
        if (mounted) setState(() => _phase = _Phase.notFound);
        return;
      }
      final cached = await ref
          .read(locationRepositoryProvider)
          .cachedLocation();
      if (cached == null) {
        if (mounted) setState(() => _phase = _Phase.error);
        return;
      }
      final preference = await ref
          .read(onboardingRepositoryProvider)
          .dietaryPreference();
      final page = await ref
          .read(catalogRepositoryProvider)
          .discoverBags(
            DiscoverQuery(
              anchor: cached.latLng,
              acceptedEnvelopes: (preference ?? DietaryPreference.everything)
                  .acceptedEnvelopes,
              categories: {widget.categoryId},
            ),
          );
      if (!mounted) return;
      setState(() {
        _categoryLabel = tag.label;
        _items = page.items;
        _phase = _Phase.loaded;
      });
    } on Object {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        elevation: 0,
        title: Text(
          _phase == _Phase.loaded ? _categoryLabel : '',
          style: context.type.title,
        ),
      ),
      body: SafeArea(child: _buildBody(context, l10n)),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    final colors = context.colors;
    switch (_phase) {
      case _Phase.loading:
        return const Center(child: CircularProgressIndicator());
      case _Phase.notFound:
      case _Phase.error:
        return Center(
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
                const SizedBox(height: Space.x4),
                TextButton(
                  onPressed: () => const DiscoverRoute().go(context),
                  child: Text(l10n.back),
                ),
              ],
            ),
          ),
        );
      case _Phase.loaded:
        if (_items.isEmpty) {
          return Center(
            child: Text(
              l10n.overFilteredTitle,
              style: context.type.body.copyWith(color: colors.textSecondary),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.x4,
            vertical: Space.x2,
          ),
          children: [
            for (final bag in _items) ...[
              BagCard(
                bag: bag,
                dietaryLabel: dietaryEnvelopeLabel(bag.dietaryEnvelope, l10n),
                clock: const SystemClock(),
                onTap: () =>
                    DiscoverBagRoute(bagId: bag.id).push<void>(context),
              ),
              const SizedBox(height: Space.listGap),
            ],
          ],
        );
    }
  }
}
