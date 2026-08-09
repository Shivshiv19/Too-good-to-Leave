import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/core/utils/formatters.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/components/max_width_body.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/domain/shop_bag.dart';
import 'package:too_good_to_leave_shop/screens/bag_edit_screen.dart';

class BagListScreen extends StatelessWidget {
  const BagListScreen({required this.repository, super.key});

  final ShopRepository repository;

  void _openEditor(BuildContext context, [ShopBag? bag]) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BagEditScreen(repository: repository, existing: bag),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        final bags = repository.getBags();
        return Scaffold(
          backgroundColor: colors.surfaceBase,
          appBar: AppBar(
            backgroundColor: colors.surfaceBase,
            title: Text('Your bags', style: context.type.title),
          ),
          body: bags.isEmpty
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
                  child: MaxWidthBody(
                    child: Wrap(
                      spacing: Space.x3,
                      runSpacing: Space.x3,
                      children: [
                        for (final bag in bags)
                          SizedBox(
                            width: 400,
                            child: _BagCard(
                              bag: bag,
                              onTap: () => _openEditor(context, bag),
                              onToggleAvailability: () =>
                                  repository.toggleAvailability(bag.id),
                              onDuplicate: () =>
                                  repository.duplicateBag(bag.id),
                            ),
                          ),
                      ],
                    ),
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
                        Row(
                          children: [
                            Text(
                              '${Fmt.money(bag.price)} · ${bag.quantityAvailable} left',
                              style: context.type.label,
                            ),
                            if (bag.repeatsDaily) ...[
                              const SizedBox(width: Space.x2),
                              Icon(
                                Icons.repeat,
                                size: 14,
                                color: colors.textTertiary,
                              ),
                            ],
                          ],
                        ),
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
