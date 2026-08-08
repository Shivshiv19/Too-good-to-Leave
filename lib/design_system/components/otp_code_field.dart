import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:surplus_marketplace/app/theme/app_colors.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// Segmented numeric code entry (Phase 6 handoff — "segmented 6-digit code
/// input"; Phase 5a §5a.7).
///
/// **Presents as one logical field, not six.** The visible boxes are purely
/// decorative, drawn from a single [controller]'s value; the actual input
/// target is one real, invisible `TextField` layered underneath them. A
/// screen reader — and autofill — sees one text field with [semanticLabel],
/// never six separate inputs to traverse. Per §5a.7, treating each box as
/// its own field is "the single most common accessibility defect in OTP
/// screens."
class OtpCodeField extends StatefulWidget {
  const OtpCodeField({
    required this.length,
    required this.controller,
    required this.semanticLabel,
    this.onCompleted,
    this.autofocus = false,
    super.key,
  });

  final int length;
  final TextEditingController controller;
  final String semanticLabel;

  /// Called once, the instant the field reaches [length] digits — drives
  /// auto-submit (§5a.7).
  final ValueChanged<String>? onCompleted;

  final bool autofocus;

  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleChange);
    super.dispose();
  }

  void _handleChange() {
    setState(() {});
    if (widget.controller.text.length == widget.length) {
      widget.onCompleted?.call(widget.controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = widget.controller.text;

    return Semantics(
      textField: true,
      label: widget.semanticLabel,
      value: text,
      excludeSemantics: true,
      child: SizedBox(
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < widget.length; i++)
                  _DigitBox(
                    digit: i < text.length ? text[i] : null,
                    isCurrent: i == text.length,
                    colors: colors,
                  ),
              ],
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: widget.controller,
                  autofocus: widget.autofocus,
                  keyboardType: TextInputType.number,
                  maxLength: widget.length,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(counterText: ''),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DigitBox extends StatelessWidget {
  const _DigitBox({
    required this.digit,
    required this.isCurrent,
    required this.colors,
  });

  final String? digit;
  final bool isCurrent;
  final AppColors colors;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 56,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(Radii.sm),
      border: Border.all(
        color: isCurrent ? colors.actionSecondaryBorder : colors.borderSubtle,
        width: isCurrent ? 2 : 1,
      ),
    ),
    child: Text(digit ?? '', style: context.type.codeMono),
  );
}
