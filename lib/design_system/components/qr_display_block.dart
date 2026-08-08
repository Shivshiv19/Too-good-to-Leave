import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// The pickup QR (§5d.3), presented as a peer of the fallback code, never a
/// substitute for it — a QR is inaccessible by nature, so this block never
/// appears without a `MonospaceCodeDisplay` alongside it.
///
/// **A21 — fixed light surface.** The QR always renders on a white card
/// regardless of the app's dark/light theme; an inverted QR against a dark
/// background is a real scanning-failure risk many phone cameras hit, and
/// scannability outranks visual consistency here.
///
/// **[Layout.qrMinSize] is a floor, never shrunk for text scaling** (§5d.3) —
/// the caller's scroll view is what accommodates `textScaleFactor` 2.0, not
/// this widget.
class QrDisplayBlock extends StatelessWidget {
  const QrDisplayBlock({required this.payload, this.dimmed = false, super.key});

  final String payload;

  /// True while serving a rotation-failed / offline fallback layer — dims
  /// the QR slightly so the offline indicator reads as authoritative
  /// rather than the two looking identical (§5d.3's error-state rule:
  /// never show an error when a valid cached token exists, but still be
  /// honest that this isn't the freshest layer).
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      // The QR itself carries no independent meaning to a screen reader —
      // MonospaceCodeDisplay's fallback code is the accessible equivalent
      // (§5d.3's own accessibility requirement).
      child: Opacity(
        opacity: dimmed ? 0.6 : 1,
        child: Container(
          padding: const EdgeInsets.all(Space.x4),
          decoration: BoxDecoration(
            color: Colors.white, // A21 — fixed, not `context.colors`.
            borderRadius: BorderRadius.circular(Radii.card),
          ),
          child: QrImageView(
            data: payload,
            version: QrVersions.auto,
            size: Layout.qrMinSize,
            backgroundColor: Colors.white,
          ),
        ),
      ),
    );
  }
}
