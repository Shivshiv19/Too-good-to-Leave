import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/app/theme/dietary_marks.dart';
import 'package:surplus_marketplace/core/domain/dietary_envelope.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// The dietary guarantee shown on every bag surface.
///
/// ## The label is not optional
///
/// [label] is a **required** constructor parameter, deliberately. §C6 mandates a
/// text label alongside the mark, and making it required means the component
/// cannot be constructed in a non-compliant state — a stronger guarantee than a
/// documentation note or a review comment.
///
/// Three reasons the mark alone is insufficient: the convention is Indian rather
/// than universal; it is inaccessible to screen readers; and for the
/// egg-containing case there is **no regulatory standard at all**, so the mark is
/// our own invention (A22).
///
/// ## Amendment A22
///
/// The mark's colour is fixed and theme-invariant. In dark mode a light chip is
/// placed behind it, because the conventional green is low-contrast on a dark
/// surface — the mark keeps its recognisable colour and the chip supplies the
/// contrast.
///
/// Shape also carries the distinction independently of colour (circle /
/// triangle / square), so the component remains legible with colour vision
/// deficiency.
class DietaryMarkChip extends StatelessWidget {
  const DietaryMarkChip({
    required this.envelope,
    required this.label,
    this.compact = false,
    super.key,
  });

  /// What the bag contains.
  final DietaryEnvelope envelope;

  /// Localised text label — *"Pure vegetarian"*, *"Contains egg"*.
  ///
  /// Required. See the class doc.
  final String label;

  /// Mark only, with the label carried in semantics.
  ///
  /// For genuinely dense surfaces such as a map peek card. Even here the label
  /// remains in the accessibility tree — [compact] hides it visually, never
  /// semantically.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final markColor = DietaryMarks.colorFor(envelope);
    final shape = DietaryMarks.shapeFor(envelope);
    final needsChip = DietaryMarks.needsLightChip(context.brightness);

    final mark = _DietaryMark(color: markColor, shape: shape);

    final marker = needsChip
        ? Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: DietaryMarks.darkModeChip,
              borderRadius: BorderRadius.circular(4),
            ),
            child: mark,
          )
        : mark;

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          marker,
          if (!compact) ...[
            const SizedBox(width: Space.x2),
            Flexible(
              child: Text(
                label,
                style: context.type.caption.copyWith(
                  color: context.colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                // Wraps rather than truncates at high text scale (§C6).
                softWrap: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The mark itself: a filled shape inside a squared outline, per the Indian
/// convention.
class _DietaryMark extends StatelessWidget {
  const _DietaryMark({required this.color, required this.shape});

  final Color color;
  final DietaryMarkShape shape;

  static const _size = 16.0;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _size,
    height: _size,
    child: CustomPaint(
      painter: _MarkPainter(color: color, shape: shape),
    ),
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.color, required this.shape});

  final Color color;
  final DietaryMarkShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Squared outline, common to all marks.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5),
        const Radius.circular(2),
      ),
      outline,
    );

    final centre = Offset(size.width / 2, size.height / 2);
    final inner = size.width * 0.28;

    switch (shape) {
      case DietaryMarkShape.circle:
        canvas.drawCircle(centre, inner, fill);
      case DietaryMarkShape.triangle:
        final path = Path()
          ..moveTo(centre.dx, centre.dy - inner)
          ..lineTo(centre.dx + inner, centre.dy + inner)
          ..lineTo(centre.dx - inner, centre.dy + inner)
          ..close();
        canvas.drawPath(path, fill);
      case DietaryMarkShape.square:
        canvas.drawRect(
          Rect.fromCenter(center: centre, width: inner * 2, height: inner * 2),
          fill,
        );
    }
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.shape != shape;
}
