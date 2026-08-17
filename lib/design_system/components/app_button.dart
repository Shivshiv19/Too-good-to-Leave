import 'dart:async';

import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/domain/money.dart';
import 'package:surplus_marketplace/core/utils/formatters.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/design_system/foundations/motion.dart';

/// Button emphasis (Phase 6b §6b.1).
enum AppButtonVariant { primary, secondary, tertiary, destructive }

/// Button height. [small] is never used for a primary action.
enum AppButtonSize {
  large(52),
  medium(44),
  small(36);

  const AppButtonSize(this.height);

  final double height;
}

/// The application's button.
///
/// Three behaviours here are requirements rather than polish:
///
/// 1. **Loading does not change the button's width.** The label stays in the
///    tree at zero opacity with the spinner overlaid, so intrinsic width is
///    preserved. A button that reflows under the user's thumb causes mis-taps —
///    and this button is sometimes the one that spends money.
/// 2. **The spinner is deferred by 400 ms** (§C1), but the button disables
///    *immediately*. Those are different concerns: the disable prevents a double
///    submit, while an indicator that flashes for 150 ms reads as a glitch.
/// 3. **A disabled button always has a reason** available as text (§5e.3). A
///    silently dead control is indistinguishable from a bug.
class AppButton extends StatefulWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.large,
    this.isLoading = false,
    this.disabledReason,
    this.icon,
    this.expand = true,
    super.key,
  });

  /// A button carrying a monetary amount.
  ///
  /// The amount becomes part of both the visible label and the semantic label.
  /// A button announced only as *"Pay"* immediately before debiting an account
  /// is an unacceptable ambiguity for a screen-reader user (§5c.2).
  factory AppButton.amount({
    required String labelPrefix,
    required Money amount,
    required VoidCallback? onPressed,
    AppButtonVariant variant = AppButtonVariant.primary,
    AppButtonSize size = AppButtonSize.large,
    bool isLoading = false,
    String? disabledReason,
    String? subtext,
    Key? key,
  }) => AppButton(
    key: key,
    label: '$labelPrefix ${Fmt.money(amount)}',
    onPressed: onPressed,
    variant: variant,
    size: size,
    isLoading: isLoading,
    disabledReason: disabledReason,
  );

  /// Visible and semantic label. States the **action**, not the location.
  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;

  /// Why the button is unavailable. Announced with the label so the disabled
  /// state is explicable rather than merely inert.
  final String? disabledReason;

  final IconData? icon;

  /// Whether to fill the available width.
  final bool expand;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  Timer? _indicatorTimer;
  bool _showIndicator = false;

  /// Starbucks-inspired rebrand's signature press feedback — every filled
  /// or outlined tap target compresses to 95% on press, everywhere,
  /// without exception. Driven by [InkWell.onHighlightChanged] rather than
  /// a separate `GestureDetector`, since `InkWell` already tracks the exact
  /// press state this needs — a second gesture arena entrant would only
  /// risk fighting the first for the tap.
  bool _pressed = false;

  @override
  void didUpdateWidget(AppButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      _syncIndicator();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.isLoading) _syncIndicator();
  }

  void _syncIndicator() {
    _indicatorTimer?.cancel();
    if (!widget.isLoading) {
      if (_showIndicator) setState(() => _showIndicator = false);
      return;
    }
    // §C1 — the 400 ms rule, enforced in the component rather than left to
    // every call site to remember.
    _indicatorTimer = Timer(Motion.indicatorDelay, () {
      if (mounted && widget.isLoading) setState(() => _showIndicator = true);
    });
  }

  @override
  void dispose() {
    _indicatorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    final (bg, fg, border) = switch (widget.variant) {
      AppButtonVariant.primary => (
        colors.actionPrimaryBg,
        colors.actionPrimaryFg,
        null,
      ),
      AppButtonVariant.secondary => (
        Colors.transparent,
        colors.actionSecondaryFg,
        colors.actionSecondaryBorder,
      ),
      AppButtonVariant.tertiary => (
        Colors.transparent,
        colors.actionSecondaryFg,
        null,
      ),
      AppButtonVariant.destructive => (
        colors.actionDestructiveBg,
        colors.actionDestructiveFg,
        null,
      ),
    };

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 20, color: fg),
          const SizedBox(width: Space.x2),
        ],
        Flexible(
          child: Text(
            widget.label,
            style: context.type.label.copyWith(color: fg),
            textAlign: TextAlign.center,
            // No maxLines: 1 — the label must survive textScaleFactor 2.0 by
            // wrapping rather than truncating (§C6). Truncating a button that
            // spends money is worse than a taller button.
            softWrap: true,
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: widget.label,
      hint: !isEnabled ? widget.disabledReason : null,
      // Excluded so the composed label above is authoritative, rather than the
      // screen reader also reading the raw Text child.
      excludeSemantics: true,
      child: Opacity(
        opacity: isEnabled || widget.isLoading ? 1 : 0.45,
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1,
          duration: context.motion(Motion.quick),
          curve: Curves.easeOut,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: Layout.minTouchTarget,
              minWidth: widget.expand
                  ? double.infinity
                  : Layout.minTouchTarget,
            ),
            child: Material(
              color: bg,
              // `Material` asserts against setting both `shape` and
              // `borderRadius` — when there's a border, `shape` alone (which
              // already carries its own `borderRadius`) must express the
              // rounding instead.
              borderRadius: border == null
                  ? BorderRadius.circular(Radii.full)
                  : null,
              shape: border == null
                  ? null
                  : RoundedRectangleBorder(
                      side: BorderSide(color: border, width: 1.5),
                      borderRadius: BorderRadius.circular(Radii.full),
                    ),
              child: InkWell(
                onTap: isEnabled ? widget.onPressed : null,
                onHighlightChanged: (value) =>
                    setState(() => _pressed = value),
                borderRadius: BorderRadius.circular(Radii.full),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.x5,
                    vertical: Space.x3,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Kept in the tree so width never changes (behaviour 1).
                      Opacity(
                        opacity: _showIndicator ? 0 : 1,
                        child: content,
                      ),
                      if (_showIndicator)
                        SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(fg),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
