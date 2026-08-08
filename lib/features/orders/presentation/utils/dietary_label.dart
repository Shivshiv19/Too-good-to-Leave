import 'package:surplus_marketplace/core/domain/dietary_envelope.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';

/// Duplicated from `catalog`'s own helper of the same name, not imported
/// from it — `orders` has no dependency on `catalog` at all (§8.3.2), and
/// this is six lines with zero behaviour to drift.
String dietaryEnvelopeLabel(DietaryEnvelope envelope, AppLocalizations l10n) =>
    switch (envelope) {
      DietaryEnvelope.pureVeg => l10n.dietaryPureVeg,
      DietaryEnvelope.containsEgg => l10n.dietaryContainsEgg,
      DietaryEnvelope.nonVeg => l10n.dietaryNonVeg,
      DietaryEnvelope.jain => l10n.dietaryJain,
    };
