import 'package:surplus_marketplace/core/domain/dietary_envelope.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';

/// Shared label lookup for [DietaryEnvelope] — every catalog surface that
/// renders a `DietaryMarkChip` needs the same localised text (§C6 mandates
/// the label; this is the one place that resolves it).
String dietaryEnvelopeLabel(DietaryEnvelope envelope, AppLocalizations l10n) =>
    switch (envelope) {
      DietaryEnvelope.pureVeg => l10n.dietaryPureVeg,
      DietaryEnvelope.containsEgg => l10n.dietaryContainsEgg,
      DietaryEnvelope.nonVeg => l10n.dietaryNonVeg,
      DietaryEnvelope.jain => l10n.dietaryJain,
    };
