import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/core/utils/formatters.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/review.dart';
import 'package:surplus_marketplace/features/catalog/presentation/providers/catalog_providers.dart';

/// §5b.11 — reached from the merchant profile. Not in the §4.2 route tree
/// (unlike the filter/sort sheets it isn't explicitly "no route" either) —
/// pushed via `Navigator` rather than a typed `go_router` destination, since
/// it is only ever reached from within the merchant profile it belongs to,
/// never deep-linked to directly.
class ReviewsListScreen extends ConsumerStatefulWidget {
  const ReviewsListScreen({
    required this.merchantId,
    required this.merchantName,
    required this.ratingAverage,
    required this.ratingCount,
    required this.histogram,
    super.key,
  });

  final String merchantId;
  final String merchantName;
  final double ratingAverage;
  final int ratingCount;
  final Map<int, int> histogram;

  @override
  ConsumerState<ReviewsListScreen> createState() => _ReviewsListScreenState();
}

class _ReviewsListScreenState extends ConsumerState<ReviewsListScreen> {
  List<Review>? _reviews;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final page = await ref
        .read(catalogRepositoryProvider)
        .merchantReviews(widget.merchantId);
    if (mounted) setState(() => _reviews = page.items);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final reviews = _reviews;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        elevation: 0,
        title: Text(l10n.reviewsListTitle, style: context.type.title),
      ),
      body: SafeArea(
        child: reviews == null
            ? const Center(child: CircularProgressIndicator())
            : reviews.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(Space.x6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.reviewsEmptyTitle, style: context.type.title),
                      const SizedBox(height: Space.x2),
                      Text(
                        l10n.reviewsEmptyBody(widget.merchantName),
                        style: context.type.body.copyWith(
                          color: colors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(Space.x4),
                children: [
                  _Histogram(
                    average: widget.ratingAverage,
                    count: widget.ratingCount,
                    histogram: widget.histogram,
                    l10n: l10n,
                  ),
                  const SizedBox(height: Space.x6),
                  for (final review in reviews) ...[
                    _ReviewTile(review: review, l10n: l10n),
                    const Divider(),
                  ],
                ],
              ),
      ),
    );
  }
}

class _Histogram extends StatelessWidget {
  const _Histogram({
    required this.average,
    required this.count,
    required this.histogram,
    required this.l10n,
  });

  final double average;
  final int count;
  final Map<int, int> histogram;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: l10n.merchantRatingSemantic(average.toStringAsFixed(1), count),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Text(
              average.toStringAsFixed(1),
              style: context.type.display,
            ),
          ),
          const SizedBox(height: Space.x2),
          for (var star = 5; star >= 1; star--) ...[
            ExcludeSemantics(
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    child: Text('$star', style: context.type.caption),
                  ),
                  const SizedBox(width: Space.x2),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.sm),
                      child: LinearProgressIndicator(
                        value:
                            (histogram[star] ?? 0) / (count == 0 ? 1 : count),
                        backgroundColor: colors.borderSubtle,
                        color: colors.success.fg,
                        minHeight: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              label: l10n.reviewsHistogramSemantic(
                star,
                histogram[star] ?? 0,
                count == 0
                    ? '0'
                    : (((histogram[star] ?? 0) / count) * 100).toStringAsFixed(
                        0,
                      ),
              ),
              child: const SizedBox(height: Space.x1),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review, required this.l10n});

  final Review review;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.x3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, size: 16, color: colors.success.fg),
                const SizedBox(width: Space.x1),
                Text('${review.rating}/5', style: context.type.label),
                const SizedBox(width: Space.x2),
                Text(
                  Fmt.relativeTime(review.createdAt, const SystemClock()),
                  style: context.type.caption.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
            if (review.comment != null) ...[
              const SizedBox(height: Space.x1),
              Text(review.comment!, style: context.type.body),
            ],
            if (review.tags.isNotEmpty) ...[
              const SizedBox(height: Space.x2),
              Wrap(
                spacing: Space.x1,
                children: [
                  for (final tag in review.tags)
                    Chip(
                      label: Text(tag, style: context.type.caption),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
