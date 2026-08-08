import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/domain/dietary_envelope.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/components/facet_chip.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/discover_query.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/discover_sort.dart';
import 'package:surplus_marketplace/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:surplus_marketplace/features/config/presentation/providers/config_providers.dart';
import 'package:surplus_marketplace/features/onboarding/presentation/providers/onboarding_providers.dart';

const _distanceOptionsKm = [1, 3, 5, 10];
const _ratingOptions = [3.0, 4.0, 4.5];

/// A fixed price band, since the spec leaves the exact bands to product
/// judgement (§2.3 only names "Price band, range"). Bounded to three
/// options rather than a slider — a slider needs its own accessible
/// stepping affordance to meet §C6, which is unbuilt scope beyond this
/// step.
enum _PriceBand {
  any(null, null),
  under100(null, 10000),
  between100And200(10000, 20000),
  above200(20000, null);

  const _PriceBand(this.minPaise, this.maxPaise);

  final int? minPaise;
  final int? maxPaise;
}

/// §5b.4 — bottom sheet, no route. Edits the URL facet state (§4.5).
class FilterSheet extends ConsumerStatefulWidget {
  const FilterSheet({required this.initial, super.key});

  final DiscoverQuery initial;

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  late DiscoverQuery _draft;
  DietaryPreference? _storedPreference;
  int? _liveCount;
  bool _counting = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
    _loadStoredPreference();
    _recount();
  }

  Future<void> _loadStoredPreference() async {
    final preference = await ref
        .read(onboardingRepositoryProvider)
        .dietaryPreference();
    if (mounted) setState(() => _storedPreference = preference);
  }

  Future<void> _recount() async {
    setState(() => _counting = true);
    try {
      final page = await ref
          .read(catalogRepositoryProvider)
          .discoverBags(_draft);
      if (mounted) {
        setState(() {
          _liveCount = page.items.length;
          _counting = false;
        });
      }
    } on Object {
      // §5b.4 — a broken convenience feature must not block Apply.
      if (mounted) {
        setState(() {
          _liveCount = null;
          _counting = false;
        });
      }
    }
  }

  void _update(DiscoverQuery Function(DiscoverQuery) transform) {
    setState(() => _draft = transform(_draft));
    _recount();
  }

  bool get _isWideningDietary {
    final stored = _storedPreference;
    if (stored == null) return false;
    return !stored.acceptedEnvelopes.containsAll(_draft.acceptedEnvelopes) ||
        _draft.acceptedEnvelopes.length > stored.acceptedEnvelopes.length;
  }

  _PriceBand get _selectedBand => _PriceBand.values.firstWhere(
    (b) =>
        b.minPaise == _draft.priceMinPaise &&
        b.maxPaise == _draft.priceMaxPaise,
    orElse: () => _PriceBand.any,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final taxonomy = ref.watch(taxonomyProvider);

    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.x4),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.x3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.filterSheetTitle, style: context.type.title),
                    TextButton(
                      onPressed: () => _update(
                        (q) => DiscoverQuery(
                          anchor: q.anchor,
                          acceptedEnvelopes: q.acceptedEnvelopes,
                          sort: q.sort,
                        ),
                      ),
                      child: Text(l10n.filterResetCta),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    if (_isWideningDietary) ...[
                      _WideningNotice(text: l10n.dietaryWideningNote),
                      const SizedBox(height: Space.x3),
                    ],
                    _FilterGroup(
                      title: l10n.filterDietaryGroup,
                      child: Wrap(
                        spacing: Space.x2,
                        runSpacing: Space.x2,
                        children: [
                          for (final envelope in DietaryEnvelope.values)
                            FacetChip(
                              label: _dietaryChipLabel(envelope, l10n),
                              active: _draft.acceptedEnvelopes.contains(
                                envelope,
                              ),
                              onTap: () => _update((q) {
                                final next = {...q.acceptedEnvelopes};
                                if (next.contains(envelope)) {
                                  next.remove(envelope);
                                } else {
                                  next.add(envelope);
                                }
                                return q.copyWith(acceptedEnvelopes: next);
                              }),
                            ),
                        ],
                      ),
                    ),
                    _FilterGroup(
                      title: l10n.filterPickupTimeGroup,
                      child: Wrap(
                        spacing: Space.x2,
                        children: [
                          FacetChip(
                            label: l10n.discoverPickupTimeAvailableNow,
                            active:
                                _draft.pickupTimeFacet ==
                                PickupTimeFacet.availableNow,
                            onTap: () => _update(
                              (q) => q.copyWith(
                                pickupTimeFacet: PickupTimeFacet.availableNow,
                              ),
                            ),
                          ),
                          FacetChip(
                            label: l10n.discoverSectionLaterToday,
                            active:
                                _draft.pickupTimeFacet ==
                                PickupTimeFacet.laterToday,
                            onTap: () => _update(
                              (q) => q.copyWith(
                                pickupTimeFacet: PickupTimeFacet.laterToday,
                              ),
                            ),
                          ),
                          FacetChip(
                            label: l10n.discoverSectionTomorrow,
                            active:
                                _draft.pickupTimeFacet ==
                                PickupTimeFacet.tomorrow,
                            onTap: () => _update(
                              (q) => q.copyWith(
                                pickupTimeFacet: PickupTimeFacet.tomorrow,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _FilterGroup(
                      title: l10n.filterDistanceGroup,
                      child: Wrap(
                        spacing: Space.x2,
                        children: [
                          for (final km in _distanceOptionsKm)
                            FacetChip(
                              label: '$km km',
                              active: _draft.radiusKm == km,
                              onTap: () =>
                                  _update((q) => q.copyWith(radiusKm: km)),
                            ),
                        ],
                      ),
                    ),
                    _FilterGroup(
                      title: l10n.filterPriceGroup,
                      child: Wrap(
                        spacing: Space.x2,
                        children: [
                          for (final band in _PriceBand.values)
                            FacetChip(
                              label: _priceBandLabel(band, l10n),
                              active: _selectedBand == band,
                              onTap: () => _update(
                                (q) => q.copyWith(
                                  priceMinPaise: band.minPaise,
                                  priceMaxPaise: band.maxPaise,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    taxonomy.when(
                      data: (t) => Column(
                        children: [
                          _FilterGroup(
                            title: l10n.filterCategoryGroup,
                            child: Wrap(
                              spacing: Space.x2,
                              runSpacing: Space.x2,
                              children: [
                                for (final tag in t.categories)
                                  FacetChip(
                                    label: tag.label,
                                    active: _draft.categories.contains(tag.id),
                                    onTap: () => _update((q) {
                                      final next = {...q.categories};
                                      next.contains(tag.id)
                                          ? next.remove(tag.id)
                                          : next.add(tag.id);
                                      return q.copyWith(categories: next);
                                    }),
                                  ),
                              ],
                            ),
                          ),
                          _FilterGroup(
                            title: l10n.filterFoodTypeGroup,
                            child: Wrap(
                              spacing: Space.x2,
                              runSpacing: Space.x2,
                              children: [
                                for (final tag in t.foodTypes)
                                  FacetChip(
                                    label: tag.label,
                                    active: _draft.foodTypes.contains(tag.id),
                                    onTap: () => _update((q) {
                                      final next = {...q.foodTypes};
                                      next.contains(tag.id)
                                          ? next.remove(tag.id)
                                          : next.add(tag.id);
                                      return q.copyWith(foodTypes: next);
                                    }),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    _FilterGroup(
                      title: l10n.filterMinRatingGroup,
                      child: Wrap(
                        spacing: Space.x2,
                        children: [
                          for (final rating in _ratingOptions)
                            FacetChip(
                              label: '${rating.toStringAsFixed(1)}+',
                              active: _draft.minRating == rating.round(),
                              onTap: () => _update(
                                (q) => q.copyWith(minRating: rating.round()),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.x4),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.x4),
                child: AppButton(
                  label: l10n.filterApplyCta(_liveCount ?? 0),
                  isLoading: _counting,
                  onPressed: () => Navigator.of(context).pop(_draft),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dietaryChipLabel(DietaryEnvelope envelope, AppLocalizations l10n) =>
      switch (envelope) {
        DietaryEnvelope.pureVeg => l10n.dietaryPureVeg,
        DietaryEnvelope.containsEgg => l10n.dietaryContainsEgg,
        DietaryEnvelope.nonVeg => l10n.dietaryNonVeg,
        DietaryEnvelope.jain => l10n.dietaryJain,
      };

  String _priceBandLabel(_PriceBand band, AppLocalizations l10n) =>
      switch (band) {
        _PriceBand.any => l10n.filterPriceAny,
        _PriceBand.under100 => l10n.filterPriceUnder100,
        _PriceBand.between100And200 => l10n.filterPrice100To200,
        _PriceBand.above200 => l10n.filterPriceAbove200,
      };
}

class _FilterGroup extends StatelessWidget {
  const _FilterGroup({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.x5),
    child: Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.type.label.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: Space.x2),
          child,
        ],
      ),
    ),
  );
}

class _WideningNotice extends StatelessWidget {
  const _WideningNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.x3),
      decoration: BoxDecoration(
        color: colors.attention.bg,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Text(
        text,
        style: context.type.body.copyWith(color: colors.attention.fg),
      ),
    );
  }
}
