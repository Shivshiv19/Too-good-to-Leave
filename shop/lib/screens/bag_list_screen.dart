import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/core/utils/formatters.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/components/app_button.dart';
import 'package:too_good_to_leave_shop/design_system/components/side_panel.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/domain/shop_bag.dart';
import 'package:too_good_to_leave_shop/screens/bag_edit_screen.dart';

/// A live bag at or below this stock level gets a low-stock badge.
const _lowStockThreshold = 2;

class BagListScreen extends StatefulWidget {
  const BagListScreen({required this.repository, super.key});

  final ShopRepository repository;

  @override
  State<BagListScreen> createState() => _BagListScreenState();
}

class _BagListScreenState extends State<BagListScreen> {
  String? _tagFilter;

  void _openEditor(BuildContext context, [ShopBag? bag]) {
    openDetail<void>(
      context,
      (_) => BagEditScreen(repository: widget.repository, existing: bag),
    );
  }

  Future<void> _duplicateAllLive(BuildContext context) async {
    final created = await widget.repository.duplicateAllLiveBagsForTomorrow();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          created.isEmpty
              ? 'No live bags to duplicate.'
              : 'Duplicated ${created.length} bag'
                    '${created.length == 1 ? '' : 's'} for tomorrow.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final allBags = widget.repository.getBags();
        final bags = _tagFilter == null
            ? allBags
            : allBags.where((b) => b.tags.contains(_tagFilter)).toList();
        final lowStockCount = allBags
            .where(
              (b) =>
                  b.status == BagStatus.live &&
                  b.quantityAvailable > 0 &&
                  b.quantityAvailable <= _lowStockThreshold,
            )
            .length;
        final hasLiveBags = allBags.any((b) => b.status == BagStatus.live);

        return Scaffold(
          backgroundColor: colors.surfaceBase,
          appBar: AppBar(
            backgroundColor: colors.surfaceBase,
            title: Text('Your bags', style: context.type.title),
            actions: [
              if (hasLiveBags)
                Padding(
                  padding: const EdgeInsets.only(right: Space.x3),
                  child: AppButton(
                    label: 'Duplicate all live for tomorrow',
                    variant: AppButtonVariant.tertiary,
                    icon: Icons.copy_all_outlined,
                    expand: false,
                    onPressed: () => _duplicateAllLive(context),
                  ),
                ),
            ],
          ),
          body: allBags.isEmpty
              ? Center(
                  child: Text(
                    'No bags yet — add your first surprise bag.',
                    style: context.type.body.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(Space.x4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (lowStockCount > 0)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: Space.x4),
                          padding: const EdgeInsets.all(Space.x3),
                          decoration: BoxDecoration(
                            color: colors.attention.bg,
                            borderRadius: BorderRadius.circular(Radii.sm),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber,
                                size: 18,
                                color: colors.attention.fg,
                              ),
                              const SizedBox(width: Space.x2),
                              Expanded(
                                child: Text(
                                  '$lowStockCount live bag'
                                  '${lowStockCount == 1 ? ' is' : 's are'} '
                                  'running low on stock ($_lowStockThreshold '
                                  'or fewer left).',
                                  style: context.type.body.copyWith(
                                    color: colors.attention.fg,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Wrap(
                        spacing: Space.x2,
                        runSpacing: Space.x2,
                        children: [
                          _TagChip(
                            label: 'All',
                            selected: _tagFilter == null,
                            onSelected: () =>
                                setState(() => _tagFilter = null),
                          ),
                          for (final tag in bagTagOptions)
                            _TagChip(
                              label: tag,
                              selected: _tagFilter == tag,
                              onSelected: () =>
                                  setState(() => _tagFilter = tag),
                            ),
                        ],
                      ),
                      const SizedBox(height: Space.x4),
                      if (bags.isEmpty)
                        Text(
                          'No bags with this tag.',
                          style: context.type.body.copyWith(
                            color: colors.textSecondary,
                          ),
                        )
                      else
                        Wrap(
                          spacing: Space.x3,
                          runSpacing: Space.x3,
                          children: [
                            for (final bag in bags)
                              SizedBox(
                                width: 400,
                                child: _BagCard(
                                  bag: bag,
                                  onTap: () => _openEditor(context, bag),
                                  onToggleAvailability: () => widget.repository
                                      .toggleAvailability(bag.id),
                                  onDuplicate: () =>
                                      widget.repository.duplicateBag(bag.id),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openEditor(context),
            backgroundColor: colors.actionPrimaryBg,
            foregroundColor: colors.actionPrimaryFg,
            icon: const Icon(Icons.add),
            label: const Text('Add bag'),
          ),
        );
      },
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: selected ? colors.actionPrimaryBg : colors.surfaceRaised,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.sm),
        onTap: onSelected,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.x3,
            vertical: Space.x2,
          ),
          child: Text(
            label,
            style: context.type.label.copyWith(
              color: selected ? colors.actionPrimaryFg : colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _BagCard extends StatelessWidget {
  const _BagCard({
    required this.bag,
    required this.onTap,
    required this.onToggleAvailability,
    required this.onDuplicate,
  });

  final ShopBag bag;
  final VoidCallback onTap;
  final VoidCallback onToggleAvailability;
  final VoidCallback onDuplicate;

  bool get _isLowStock =>
      bag.status == BagStatus.live &&
      bag.quantityAvailable > 0 &&
      bag.quantityAvailable <= _lowStockThreshold;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.surfaceRaised,
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BagThumbnail(bag: bag),
                  const SizedBox(width: Space.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(bag.title, style: context.type.title),
                            ),
                            _StatusChip(status: bag.status),
                          ],
                        ),
                        const SizedBox(height: Space.x1),
                        Text(
                          bag.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.type.body.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: Space.x2),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: Space.x2,
                          runSpacing: Space.x1,
                          children: [
                            Text(
                              '${Fmt.money(bag.price)} · ${bag.quantityAvailable} left',
                              style: context.type.label,
                            ),
                            if (bag.repeatsDaily)
                              Icon(
                                Icons.repeat,
                                size: 14,
                                color: colors.textTertiary,
                              ),
                            if (_isLowStock)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Space.x2,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.attention.bg,
                                  borderRadius: BorderRadius.circular(
                                    Radii.full,
                                  ),
                                ),
                                child: Text(
                                  'Low stock',
                                  style: context.type.caption.copyWith(
                                    color: colors.attention.fg,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (bag.tags.isNotEmpty) ...[
                          const SizedBox(height: Space.x1),
                          Text(
                            bag.tags.join(' · '),
                            style: context.type.caption.copyWith(
                              color: colors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: Space.x6),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Space.x2,
                runSpacing: Space.x2,
                children: [
                  if (bag.status != BagStatus.draft)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          bag.status == BagStatus.live ? 'Live' : 'Paused',
                          style: context.type.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        Switch(
                          value: bag.status == BagStatus.live,
                          onChanged: (_) => onToggleAvailability(),
                        ),
                      ],
                    ),
                  TextButton.icon(
                    onPressed: onDuplicate,
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: const Text('Duplicate for tomorrow'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BagThumbnail extends StatelessWidget {
  const _BagThumbnail({required this.bag});

  final ShopBag bag;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final photoBytes = bag.photoBytes;

    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.sm),
      child: SizedBox(
        width: 64,
        height: 64,
        child: photoBytes != null
            ? Image.memory(photoBytes, fit: BoxFit.cover)
            : DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceSunken,
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Center(
                  child: Text(
                    'photo',
                    style: context.type.caption.copyWith(
                      color: colors.textTertiary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final BagStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (label, palette) = switch (status) {
      BagStatus.live => ('Live', colors.success),
      BagStatus.paused => ('Paused', colors.attention),
      BagStatus.draft => ('Draft', colors.info),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.x2, vertical: 2),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(Radii.full),
      ),
      child: Text(
        label,
        style: context.type.caption.copyWith(
          color: palette.fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
