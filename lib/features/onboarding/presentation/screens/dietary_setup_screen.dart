import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/domain/dietary_envelope.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/components/selectable_card.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/onboarding/presentation/providers/onboarding_providers.dart';

/// Captures a hard constraint before any results are shown (§4.2
/// `/dietary-setup`, §5a.5). In India this is religious and ethical
/// identity, not a taste preference (Phase 1 §3.1).
///
/// **Scope note.** The route tree places this after `/location-primer`/
/// `/location-setup` (§4.2, Phase 8 §8.12 step 4), which now route here on
/// success — see `location_primer_screen.dart`/`location_setup_screen.dart`.
class DietarySetupScreen extends ConsumerStatefulWidget {
  const DietarySetupScreen({super.key});

  @override
  ConsumerState<DietarySetupScreen> createState() => _DietarySetupScreenState();
}

class _DietarySetupScreenState extends ConsumerState<DietarySetupScreen> {
  DietaryPreference? _selected;

  Future<void> _save(DietaryPreference preference) async {
    await ref
        .read(onboardingRepositoryProvider)
        .saveDietaryPreference(preference);
    if (mounted) context.go('/discover');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    final options = <(DietaryPreference, String)>[
      (DietaryPreference.jain, l10n.dietaryPrefJain),
      (DietaryPreference.pureVeg, l10n.dietaryPrefPureVeg),
      (DietaryPreference.vegWithEgg, l10n.dietaryPrefVegWithEgg),
      (DietaryPreference.everything, l10n.dietaryPrefEverything),
    ];

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.x6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.dietarySetupTitle,
                style: context.type.display,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Space.x8),
              for (final (preference, label) in options) ...[
                SelectableCard(
                  label: label,
                  selected: _selected == preference,
                  onSelected: () => setState(() => _selected = preference),
                ),
                const SizedBox(height: Space.x3),
              ],
              const SizedBox(height: Space.x2),
              Center(
                child: TextButton(
                  onPressed: () => _save(DietaryPreference.everything),
                  child: Text(l10n.dietaryShowEverything),
                ),
              ),
              const SizedBox(height: Space.x4),
              Text(
                l10n.dietarySetupNote,
                style: context.type.caption.copyWith(
                  color: colors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Space.x6),
              AppButton(
                label: l10n.continueCta,
                onPressed: _selected == null ? null : () => _save(_selected!),
                disabledReason: l10n.dietarySetupContinueDisabledReason,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
