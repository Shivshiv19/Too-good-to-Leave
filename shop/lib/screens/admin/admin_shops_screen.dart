import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/components/app_button.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/domain/admin_models.dart';
import 'package:too_good_to_leave_shop/domain/shop_profile.dart';
import 'package:too_good_to_leave_shop/screens/admin/reject_shop_dialog.dart';

/// Every shop, any status — where an already-verified shop gets
/// deactivated (a customer-facing problem, a request to stop listing) or a
/// previously-rejected one gets a second look. Approving/rejecting a shop
/// still waiting on its first review lives on [AdminPendingShopsScreen]
/// instead — this tab is for shops that already have a status to change.
class AdminShopsScreen extends StatefulWidget {
  const AdminShopsScreen({required this.repository, super.key});

  final ShopRepository repository;

  @override
  State<AdminShopsScreen> createState() => _AdminShopsScreenState();
}

class _AdminShopsScreenState extends State<AdminShopsScreen> {
  late Future<List<AdminShopSummary>> _future = widget.repository
      .adminGetAllShops();
  final _busyIds = <String>{};
  final _searchController = TextEditingController();
  ShopApprovalStatus? _filter;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _future = widget.repository.adminGetAllShops());
    await _future;
  }

  Future<void> _deactivate(AdminShopSummary shop) async {
    final reason = await showRejectShopDialog(
      context,
      businessName: shop.businessName,
    );
    if (reason == null) return;
    setState(() => _busyIds.add(shop.id));
    try {
      await widget.repository.adminRejectShop(shop.id, reason: reason);
      await _reload();
    } finally {
      if (mounted) setState(() => _busyIds.remove(shop.id));
    }
  }

  Future<void> _reactivate(AdminShopSummary shop) async {
    setState(() => _busyIds.add(shop.id));
    try {
      await widget.repository.adminApproveShop(shop.id);
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
        title: Text('All shops', style: context.type.title),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<AdminShopSummary>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData && !snapshot.hasError) {
              return const Center(child: CircularProgressIndicator());
            }
            final q = _query.trim().toLowerCase();
            final shops = (snapshot.data ?? const [])
                .where((s) => _filter == null || s.status == _filter)
                .where(
                  (s) =>
                      q.isEmpty ||
                      s.businessName.toLowerCase().contains(q) ||
                      s.ownerName.toLowerCase().contains(q) ||
                      s.phone.toLowerCase().contains(q) ||
                      s.city.toLowerCase().contains(q) ||
                      s.locality.toLowerCase().contains(q),
                )
                .toList();
            return ListView(
              padding: const EdgeInsets.all(Space.x4),
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search by name, owner, phone, or city',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                    isDense: true,
                    filled: true,
                    fillColor: colors.surfaceRaised,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.sm),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: Space.x3),
                Wrap(
                  spacing: Space.x2,
                  runSpacing: Space.x2,
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _filter == null,
                      onSelected: () => setState(() => _filter = null),
                    ),
                    _FilterChip(
                      label: 'Verified',
                      selected: _filter == ShopApprovalStatus.verified,
                      onSelected: () => setState(
                        () => _filter = ShopApprovalStatus.verified,
                      ),
                    ),
                    _FilterChip(
                      label: 'Pending',
                      selected: _filter == ShopApprovalStatus.pendingReview,
                      onSelected: () => setState(
                        () => _filter = ShopApprovalStatus.pendingReview,
                      ),
                    ),
                    _FilterChip(
                      label: 'Rejected',
                      selected: _filter == ShopApprovalStatus.rejected,
                      onSelected: () => setState(
                        () => _filter = ShopApprovalStatus.rejected,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.x4),
                if (snapshot.hasError)
                  Text(
                    "Couldn't load shops.",
                    style: context.type.body.copyWith(
                      color: colors.textSecondary,
                    ),
                  )
                else if (shops.isEmpty)
                  Text(
                    'No shops match this filter.',
                    style: context.type.body.copyWith(
                      color: colors.textSecondary,
                    ),
                  )
                else
                  for (final shop in shops) ...[
                    _ShopRow(
                      shop: shop,
                      busy: _busyIds.contains(shop.id),
                      onDeactivate: () => _deactivate(shop),
                      onReactivate: () => _reactivate(shop),
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final ShopApprovalStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (label, palette) = switch (status) {
      ShopApprovalStatus.verified => ('Verified', colors.success),
      ShopApprovalStatus.pendingReview => ('Pending', colors.attention),
      ShopApprovalStatus.rejected => ('Rejected', colors.critical),
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

class _ShopRow extends StatelessWidget {
  const _ShopRow({
    required this.shop,
    required this.busy,
    required this.onDeactivate,
    required this.onReactivate,
  });

  final AdminShopSummary shop;
  final bool busy;
  final VoidCallback onDeactivate;
  final VoidCallback onReactivate;

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
          Row(
            children: [
              Expanded(
                child: Text(shop.businessName, style: context.type.title),
              ),
              _StatusBadge(status: shop.status),
            ],
          ),
          const SizedBox(height: Space.x1),
          Text(
            '${shop.ownerName} · ${shop.locality}, ${shop.city}',
            style: context.type.body.copyWith(color: colors.textSecondary),
          ),
          if (shop.status == ShopApprovalStatus.rejected &&
              (shop.rejectionReason?.isNotEmpty ?? false)) ...[
            const SizedBox(height: Space.x2),
            Text(
              'Reason: ${shop.rejectionReason}',
              style: context.type.caption.copyWith(color: colors.critical.fg),
            ),
          ],
          if (shop.status != ShopApprovalStatus.pendingReview) ...[
            const SizedBox(height: Space.x3),
            Align(
              alignment: Alignment.centerRight,
              child: shop.status == ShopApprovalStatus.verified
                  ? AppButton(
                      label: 'Deactivate',
                      variant: AppButtonVariant.destructive,
                      size: AppButtonSize.small,
                      expand: false,
                      isLoading: busy,
                      onPressed: busy ? null : onDeactivate,
                    )
                  : AppButton(
                      label: 'Reactivate',
                      size: AppButtonSize.small,
                      expand: false,
                      isLoading: busy,
                      onPressed: busy ? null : onReactivate,
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
