/// §5f.9's four legal documents.
enum LegalDocId {
  terms('terms'),
  privacy('privacy'),
  refundsCancellations('refunds-cancellations'),
  grievance('grievance');

  const LegalDocId(this.wireValue);

  /// Also the `:docId` path segment (§4.2).
  final String wireValue;

  static LegalDocId? fromWire(String value) => switch (value) {
    'terms' => LegalDocId.terms,
    'privacy' => LegalDocId.privacy,
    'refunds-cancellations' => LegalDocId.refundsCancellations,
    'grievance' => LegalDocId.grievance,
    _ => null,
  };
}
