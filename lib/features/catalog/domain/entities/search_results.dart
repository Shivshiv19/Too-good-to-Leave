import 'package:surplus_marketplace/features/catalog/domain/entities/merchant_summary.dart';

/// `GET /v1/search` (Phase 7 §7.4) — merchants only, per D-b4: bag contents
/// aren't indexed, so there is nothing else to match against. "Grouped
/// results (merchants, then bags)" (§5b.3) is realised as each merchant row
/// carrying its own live-bag count, not a separate bag result list.
final class SearchResults {
  const SearchResults({required this.merchants});

  final List<MerchantResult> merchants;
}

final class MerchantResult {
  const MerchantResult({
    required this.merchant,
    required this.liveBagCount,
    required this.distanceMetres,
  });

  final MerchantSummary merchant;
  final int liveBagCount;
  final int distanceMetres;
}
