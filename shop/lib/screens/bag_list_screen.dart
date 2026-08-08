import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/core/utils/formatters.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/domain/shop_bag.dart';
import 'package:too_good_to_leave_shop/screens/bag_edit_screen.dart';

class BagListScreen extends StatefulWidget {
  const BagListScreen({required this.repository, super.key});

  final ShopRepository repository;

  @override
  State<BagListScreen> createState() => _BagListScreenState();
}

class _BagListScreenState extends State<BagListScreen> {
  late List<ShopBag> _bags = widget.repository.getBags();

  void _refresh() => setState(() => _bags = widget.repository.getBags());

  Future<void> _openEditor([ShopBag? bag]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            BagEditScreen(repository: widget.repository, existing: bag),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        title: Text('Your bags', style: context.type.title),
      ),
      body: _bags.isEmpty
          ? Center(
              child: Text(
                'No bags yet — add your first surprise bag.',
                style: context.type.body.copyWith(color: colors.textSecondary),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(Space.x4),
              itemCount: _bags.length,
              separatorBuilder: (_, _) => const SizedBox(height: Space.x3),
              itemBuilder: (context, index) {
                final bag = _bags[index];
                return _BagCard(bag: bag, onTap: () => _openEditor(bag));
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: colors.actionPrimaryBg,
        foregroundColor: colors.actionPrimaryFg,
        icon: const Icon(Icons.add),
        label: const Text('Add bag'),
      ),
    );
  }
}

class _BagCard extends StatelessWidget {
  const _BagCard({required this.bag, required this.onTap});

  final ShopBag bag;
  final VoidCallback onTap;

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
          child: Row(
            children: [
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
                    Text(
                      '${Fmt.money(bag.price)} · ${bag.quantityAvailable} left',
                      style: context.type.label,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.textTertiary),
            ],
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
