import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:surplus_marketplace/app/session/session_providers.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/core/platform/location_capability.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/location/domain/entities/location_precision.dart';
import 'package:surplus_marketplace/features/location/domain/entities/location_source.dart';
import 'package:surplus_marketplace/features/location/presentation/providers/location_providers.dart';

/// Earns the location grant by explaining the value first — the OS dialog is
/// never the user's first encounter with the request (§4.2 `/location-primer`,
/// §5a.3, D2).
class LocationPrimerScreen extends ConsumerStatefulWidget {
  const LocationPrimerScreen({this.redirect, super.key});

  /// Where to continue once a location is resolved. Defaults to
  /// `/dietary-setup` — the real next step in the first-run journey
  /// (§3.1 step 5) — when reached from onboarding rather than from a
  /// location-required route (§4.3 rule 6, not wired yet — see
  /// `router.dart`'s scope note).
  final String? redirect;

  @override
  ConsumerState<LocationPrimerScreen> createState() =>
      _LocationPrimerScreenState();
}

enum _PrimerState { initial, requesting }

class _LocationPrimerScreenState extends ConsumerState<LocationPrimerScreen> {
  _PrimerState _state = _PrimerState.initial;

  String get _destination => widget.redirect ?? '/dietary-setup';

  Future<void> _allow() async {
    setState(() => _state = _PrimerState.requesting);
    final capability = ref.read(locationCapabilityProvider);

    final LocationPermissionOutcome outcome;
    try {
      outcome = await capability.requestPermission();
    } on Object {
      // The OS dialog failing to present (§5a.3 — rare, some OEM builds)
      // surfaces here as the platform call itself throwing rather than
      // hanging; a genuinely slow user still on a real dialog is a
      // different, legitimate case we must not race against with an
      // arbitrary timer, so there is no separate 3 s clock — the fallback
      // is driven by the failure signal itself.
      if (mounted) _goManual();
      return;
    }

    if (!mounted) return;
    switch (outcome) {
      case LocationPermissionOutcome.grantedPrecise:
        await _resolveCurrentLocation(LocationPrecision.precise);
      case LocationPermissionOutcome.grantedApproximate:
        // Accepted, not re-prompted — a 5 km discovery radius tolerates
        // coarse location (§5a.3).
        await _resolveCurrentLocation(LocationPrecision.approximate);
      case LocationPermissionOutcome.denied:
      case LocationPermissionOutcome.deniedPermanently:
        _goManual();
    }
  }

  Future<void> _resolveCurrentLocation(LocationPrecision precision) async {
    try {
      final capability = ref.read(locationCapabilityProvider);
      final latLng = await capability.getCurrentPosition(
        timeout: const Duration(seconds: 15),
      );
      final resolved = await ref
          .read(locationRepositoryProvider)
          .reverseGeocode(
            latLng,
            precision: precision,
            source: LocationSource.gps,
          );
      await ref.read(locationRepositoryProvider).confirmLocation(resolved);
      if (!mounted) return;
      ref.read(sessionStateProvider).markLocationResolved();
      context.go(_destination);
    } on Object {
      // A granted permission that still fails to produce a fix (GPS
      // timeout, provider disabled) is the same "never a dead end"
      // requirement as an outright denial (§5a.3/§3.1 step 4) — the manual
      // screen's own "Use current location" retries this.
      if (mounted) _goManual();
    }
  }

  void _goManual() {
    context.go(
      '/location-setup?redirectTo=${Uri.encodeComponent(_destination)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final isRequesting = _state == _PrimerState.requesting;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.x6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isRequesting)
                Semantics(
                  liveRegion: true,
                  label: l10n.locationPrimerRequestingAnnouncement,
                  child: const SizedBox.shrink(),
                ),
              const Spacer(),
              // Decorative — the real content is the headline/body below,
              // same icon-as-illustration placeholder decision as onboarding
              // (no asset pipeline yet).
              ExcludeSemantics(
                child: Icon(
                  Icons.location_on_outlined,
                  size: 96,
                  color: colors.actionSecondaryFg,
                ),
              ),
              const SizedBox(height: Space.x8),
              Text(
                l10n.locationPrimerHeadline,
                style: context.type.display,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Space.x4),
              Text(
                l10n.locationPrimerBody1,
                style: context.type.body.copyWith(color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Space.x2),
              Text(
                l10n.locationPrimerBody2,
                style: context.type.body.copyWith(color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              AppButton(
                label: l10n.locationPrimerAllowCta,
                isLoading: isRequesting,
                onPressed: isRequesting ? null : _allow,
              ),
              const SizedBox(height: Space.x3),
              // Equal visual weight, not a greyed-out afterthought (§5a.3) —
              // for a user who will never grant location, this is the only
              // path, and de-emphasising it to inflate grant rates is a dark
              // pattern.
              AppButton(
                label: l10n.locationPrimerManualCta,
                variant: AppButtonVariant.secondary,
                onPressed: isRequesting ? null : _goManual,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
