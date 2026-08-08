import 'package:surplus_marketplace/core/error/app_exception.dart';

/// `GET /v1/me/deletion-eligibility` (§7.7, §5f.11). Reuses [DeletionBlocker]
/// from `core/error` rather than a second type — it's the same amendment-A20
/// concept whether it arrives here or attached to a thrown
/// `AccountDeletionBlockedException`.
final class DeletionEligibility {
  const DeletionEligibility({required this.eligible, required this.blockers});

  final bool eligible;
  final List<DeletionBlocker> blockers;
}
