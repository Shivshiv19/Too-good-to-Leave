import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/core/domain/money.dart';
import 'package:too_good_to_leave_shop/core/utils/formatters.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/components/app_button.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/domain/admin_models.dart';

/// What the platform still owes each shop — every collected order not yet
/// marked paid. No real payment gateway sits behind "mark as paid" yet
/// (see [ShopRepository.adminMarkShopPaid]'s own doc) — this is the
/// ledger, ready for when one exists.
class AdminPayoutsScreen extends StatefulWidget {
  const AdminPayoutsScreen({required this.repository, super.key});

  final ShopRepository repository;

  @override
  State<AdminPayoutsScreen> createState() => _AdminPayoutsScreenState();
}

class _AdminPayoutsScreenState extends State<AdminPayoutsScreen> {
  late Future<List<AdminPayoutQueueEntry>> _future = widget.repository
      .adminGetPayoutQueue();
  final _busyIds = <String>{};

  Future<void> _reload() async {
    setState(() => _future = widget.repository.adminGetPayoutQueue());
    await _future;
  }

  Future<void> _markPaid(AdminPayoutQueueEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mark ${entry.shopName} as paid?'),
        content: Text(
          'This records that you paid ${Fmt.money(Money(entry.pendingPaise))} '
          'to this shop for ${entry.orderCount} collected order'
          "${entry.orderCount == 1 ? '' : 's'}. There's no live payment "
          "gateway yet, so it doesn't move real money — you'd still send "
          'this by bank transfer yourself.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Back'),
          ),
          AppButton(
            label: 'Mark as paid',
            expand: false,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    setState(() => _busyIds.add(entry.shopId));
    try {
      await widget.repository.adminMarkShopPaid(entry.shopId);
      await _reload();
    } finally {
      if (mounted) setState(() => _busyIds.remove(entry.shopId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        title: Text('Payouts', style: context.type.title),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<AdminPayoutQueueEntry>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData && !snapshot.hasError) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: Space.x12),
                  Center(
                    child: Text(
                      "Couldn't load the payout queue.",
                      style: context.type.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              );
            }
            final entries = snapshot.data!;
            if (entries.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: Space.x12),
                  Center(
                    child: Text(
                      'Nothing owed right now — every collected order has '
                      'been paid out.',
                      textAlign: TextAlign.center,
                      style: context.type.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              );
            }
            final totalPaise = entries.fold<int>(
              0,
              (sum, e) => sum + e.pendingPaise,
            );
            return ListView(
              padding: const EdgeInsets.all(Space.x4),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Space.x4),
                  decoration: BoxDecoration(
                    color: colors.surfaceRaised,
                    borderRadius: BorderRadius.circular(Radii.card),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Fmt.money(Money(totalPaise)),
                        style: context.type.headline,
                      ),
                      Text(
                        'Total owed across ${entries.length} shop'
                        '${entries.length == 1 ? '' : 's'}',
                        style: context.type.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.x4),
                for (final entry in entries) ...[
                  _PayoutRow(
                    entry: entry,
                    busy: _busyIds.contains(entry.shopId),
                    onMarkPaid: () => _markPaid(entry),
                  ),
                  const SizedBox(height: Space.x3),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PayoutRow extends StatelessWidget {
  const _PayoutRow({
    required this.entry,
    required this.busy,
    required this.onMarkPaid,
  });

  final AdminPayoutQueueEntry entry;
  final bool busy;
  final VoidCallback onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(Space.x4),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.shopName, style: context.type.title),
                const SizedBox(height: Space.x1),
                Text(
                  '${entry.orderCount} order${entry.orderCount == 1 ? '' : 's'} '
                  'not yet paid out',
                  style: context.type.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.x3),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Fmt.money(Money(entry.pendingPaise)),
                style: context.type.title,
              ),
              const SizedBox(height: Space.x2),
              AppButton(
                label: 'Mark as paid',
                size: AppButtonSize.small,
                expand: false,
                isLoading: busy,
                onPressed: busy ? null : onMarkPaid,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
