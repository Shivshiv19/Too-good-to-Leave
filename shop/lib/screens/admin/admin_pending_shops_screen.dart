import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/components/app_button.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/domain/admin_models.dart';
import 'package:too_good_to_leave_shop/screens/admin/reject_shop_dialog.dart';

/// The back office's landing tab — shops waiting on a real review, since
/// [ShopRepository.simulateApproval] (the old self-service shortcut) no
/// longer exists. Approving/rejecting here is the only way a shop moves
/// out of `pending_review` now.
class AdminPendingShopsScreen extends StatefulWidget {
  const AdminPendingShopsScreen({required this.repository, super.key});

  final ShopRepository repository;

  @override
  State<AdminPendingShopsScreen> createState() =>
      _AdminPendingShopsScreenState();
}

class _AdminPendingShopsScreenState extends State<AdminPendingShopsScreen> {
  late Future<List<AdminShopSummary>> _future = widget.repository
      .adminGetPendingShops();
  final _busyIds = <String>{};

  Future<void> _reload() async {
    setState(() => _future = widget.repository.adminGetPendingShops());
    await _future;
  }

  Future<void> _approve(AdminShopSummary shop) async {
    setState(() => _busyIds.add(shop.id));
    try {
      await widget.repository.adminApproveShop(shop.id);
      await _reload();
    } finally {
      if (mounted) setState(() => _busyIds.remove(shop.id));
    }
  }

  Future<void> _reject(AdminShopSummary shop) async {
    final reason = await showRejectShopDialog(context, businessName: shop.businessName);
    if (reason == null) return;
    setState(() => _busyIds.add(shop.id));
    try {
      await widget.repository.adminRejectShop(shop.id, reason: reason);
      await _reload();
    } finally {
      if (mounted) setState(() => _busyIds.remove(shop.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        title: Text('Pending shops', style: context.type.title),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<AdminShopSummary>>(
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
                      "Couldn't load pending shops.",
                      style: context.type.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              );
            }
            final shops = snapshot.data!;
            if (shops.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: Space.x12),
                  Center(
                    child: Text(
                      'Nothing waiting on review.',
                      style: context.type.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(Space.x4),
              itemCount: shops.length,
              separatorBuilder: (_, _) => const SizedBox(height: Space.x3),
              itemBuilder: (context, i) {
                final shop = shops[i];
                final busy = _busyIds.contains(shop.id);
                return _PendingShopCard(
                  shop: shop,
                  busy: busy,
                  onApprove: () => _approve(shop),
                  onReject: () => _reject(shop),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _PendingShopCard extends StatelessWidget {
  const _PendingShopCard({
    required this.shop,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final AdminShopSummary shop;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(shop.businessName, style: context.type.title),
          const SizedBox(height: Space.x1),
          Text(
            '${shop.ownerName} · ${shop.phone}',
            style: context.type.body.copyWith(color: colors.textSecondary),
          ),
          if (shop.email.isNotEmpty)
            Text(
              shop.email,
              style: context.type.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
          const SizedBox(height: Space.x1),
          Text(
            '${shop.locality}, ${shop.city}',
            style: context.type.caption.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: Space.x4),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Reject',
                  variant: AppButtonVariant.destructive,
                  size: AppButtonSize.medium,
                  onPressed: busy ? null : onReject,
                ),
              ),
              const SizedBox(width: Space.x3),
              Expanded(
                child: AppButton(
                  label: 'Approve',
                  size: AppButtonSize.medium,
                  isLoading: busy,
                  onPressed: busy ? null : onApprove,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
