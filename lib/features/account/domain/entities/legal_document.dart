import 'package:surplus_marketplace/features/account/domain/entities/legal_doc_id.dart';

/// §5f.9. `bodyMarkdown` is the restricted subset only (§5f.7's rule,
/// reiterated at §5f.9) — never arbitrary HTML.
final class LegalDocument {
  const LegalDocument({
    required this.docId,
    required this.title,
    required this.version,
    required this.effectiveDate,
    required this.lastUpdated,
    required this.bodyMarkdown,
  });

  final LegalDocId docId;
  final String title;
  final String version;
  final DateTime effectiveDate;
  final DateTime lastUpdated;
  final String bodyMarkdown;
}
