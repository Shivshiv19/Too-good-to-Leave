import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/core/domain/clock.dart';
import 'package:too_good_to_leave_shop/core/utils/formatters.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/domain/admin_models.dart';

/// Every admin action, newest first — the back office's own accountability
/// trail. One admin today, but the log starts from day one rather than
/// from whenever a second admin joins.
class AdminAuditLogScreen extends StatefulWidget {
  const AdminAuditLogScreen({required this.repository, super.key});

  final ShopRepository repository;

  @override
  State<AdminAuditLogScreen> createState() => _AdminAuditLogScreenState();
}

class _AdminAuditLogScreenState extends State<AdminAuditLogScreen> {
  late Future<List<AdminAuditLogEntry>> _future = widget.repository
      .adminGetAuditLog();

  Future<void> _reload() async {
    setState(() => _future = widget.repository.adminGetAuditLog());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        title: Text('Audit log', style: context.type.title),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<AdminAuditLogEntry>>(
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
                      "Couldn't load the audit log.",
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
                      'No admin actions recorded yet.',
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
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: Space.x2),
              itemBuilder: (context, i) {
                final entry = entries[i];
                return _LogRow(
                  entry: entry,
                  clock: widget.repository.clock,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

String _actionLabel(String action) => switch (action) {
  'approve_shop' => 'Approved a shop',
  'reject_shop' => 'Rejected/deactivated a shop',
  'cancel_order' => 'Cancelled an order',
  'refund_order' => 'Refunded an order',
  'mark_shop_paid' => 'Marked a shop paid',
  _ => action,
};

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry, required this.clock});

  final AdminAuditLogEntry entry;
  final Clock clock;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(Space.x3),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_actionLabel(entry.action), style: context.type.body),
                const SizedBox(height: Space.x1),
                Text(
                  '${entry.adminEmail}'
                  '${entry.detail != null ? ' · ${entry.detail}' : ''}',
                  style: context.type.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.x3),
          Text(
            Fmt.relativeTime(entry.createdAt, clock),
            style: context.type.caption.copyWith(color: colors.textTertiary),
          ),
        ],
      ),
    );
  }
}
