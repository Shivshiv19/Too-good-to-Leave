import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/domain/pickup_window.dart';
import 'package:surplus_marketplace/core/utils/formatters.dart';

/// A live countdown to [target].
///
/// The product's core mechanic is a clock (§3.8), so this component appears on
/// the cart, checkout, orders list, order detail, and pickup screens. Four of its
/// behaviours are requirements:
///
/// 1. **Tabular figures**, from the `countdown` type role. Proportional digits
///    change width as they tick, so the text visibly jitters and reflows its
///    container — on a screen the user stares at while standing in a shop.
/// 2. **Threshold announcements only.** A per-second live region is unusable, so
///    the screen reader is told at [announceThresholds] and at expiry, politely.
/// 3. **Adaptive tick rate.** One second under a minute, twenty seconds above —
///    a per-second rebuild for a display that changes once a minute is wasted
///    work on the mid-tier devices we target (Phase 1 §3.6).
/// 4. **Never the sole mechanism.** Per §C6 / WCAG 2.2.1, whatever expires must
///    be recoverable in one tap. This widget reports expiry via [onExpired]; it
///    is the caller's job to offer that recovery.
class CountdownText extends StatefulWidget {
  const CountdownText({
    required this.target,
    required this.clock,
    this.urgency,
    this.frozen = false,
    this.frozenLabel,
    this.announceThresholds = defaultThresholds,
    this.onExpired,
    this.style,
    super.key,
  });

  /// Pickup-window thresholds (§5d.3).
  static const defaultThresholds = [
    Duration(minutes: 30),
    Duration(minutes: 10),
    Duration(minutes: 5),
  ];

  /// Cart-hold thresholds (§5c.1). Tighter, because the stake is a bag the user
  /// is actively trying to buy.
  static const holdThresholds = [
    Duration(minutes: 5),
    Duration(minutes: 2),
    Duration(minutes: 1),
    Duration(seconds: 30),
  ];

  /// The instant being counted down to.
  final DateTime target;

  /// Injected time source, so this is testable without waiting (§7.10).
  final Clock clock;

  /// Drives the colour via the §6.2.7 urgency mapping. When null the countdown
  /// derives urgency from remaining time using the window thresholds.
  final WindowUrgency? urgency;

  /// **Amendment A2** — a cart hold does not expire while its payment is in
  /// flight. A countdown that keeps ticking toward a deadline that no longer
  /// applies would be actively misleading, so the frozen state stops and
  /// explains itself.
  final bool frozen;

  /// Localised explanation shown while [frozen] — e.g. *"Held while we confirm
  /// your payment"*.
  final String? frozenLabel;

  final List<Duration> announceThresholds;

  /// Called once when the target passes.
  final VoidCallback? onExpired;

  final TextStyle? style;

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;
  late Duration _remaining;
  final _announced = <Duration>{};
  bool _expiryReported = false;

  @override
  void initState() {
    super.initState();
    _remaining = _compute();
    _schedule();
  }

  @override
  void didUpdateWidget(CountdownText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.target != oldWidget.target ||
        widget.frozen != oldWidget.frozen) {
      _announced.clear();
      _expiryReported = false;
      _remaining = _compute();
      _schedule();
    }
  }

  Duration _compute() {
    final diff = widget.target.difference(widget.clock.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  void _schedule() {
    _timer?.cancel();
    if (widget.frozen || _remaining == Duration.zero) return;

    // Behaviour 3 — adaptive cadence.
    final interval = _remaining.inMinutes < 1
        ? const Duration(seconds: 1)
        : const Duration(seconds: 20);

    _timer = Timer.periodic(interval, (_) {
      if (!mounted) return;
      final next = _compute();
      final crossed = _crossedThreshold(_remaining, next);
      setState(() => _remaining = next);

      if (crossed != null) _announce(Fmt.countdownSemantics(next));

      if (next == Duration.zero) {
        _timer?.cancel();
        if (!_expiryReported) {
          _expiryReported = true;
          // Expiry is announced assertively — unlike the threshold notices,
          // this one changes what the user can do.
          _announce('Time is up', assertive: true);
          widget.onExpired?.call();
        }
      } else if (next.inMinutes < 1 && interval.inSeconds != 1) {
        // Entered the final minute; tighten the cadence.
        _schedule();
      }
    });
  }

  /// The threshold crossed between [before] and [after], if any.
  Duration? _crossedThreshold(Duration before, Duration after) {
    for (final t in widget.announceThresholds) {
      if (before > t && after <= t && !_announced.contains(t)) {
        _announced.add(t);
        return t;
      }
    }
    return null;
  }

  void _announce(String message, {bool assertive = false}) {
    SemanticsService.announce(
      message,
      Directionality.of(context),
      assertiveness: assertive ? Assertiveness.assertive : Assertiveness.polite,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  WindowUrgency get _effectiveUrgency {
    if (widget.urgency != null) return widget.urgency!;
    if (_remaining == Duration.zero) return WindowUrgency.closed;
    return _remaining <= PickupWindow.closingSoonThreshold
        ? WindowUrgency.closingSoon
        : WindowUrgency.openNow;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (widget.frozen) {
      // A2 — static, explanatory, and deliberately neutral rather than urgent.
      return Semantics(
        liveRegion: false,
        label: widget.frozenLabel,
        excludeSemantics: true,
        child: Text(
          widget.frozenLabel ?? Fmt.countdown(_remaining),
          style: (widget.style ?? context.type.countdown).copyWith(
            color: colors.textSecondary,
          ),
        ),
      );
    }

    return Semantics(
      // Announcements are made explicitly at thresholds; marking this a live
      // region would have the screen reader read every rebuild.
      liveRegion: false,
      label: Fmt.countdownSemantics(_remaining),
      excludeSemantics: true,
      child: Text(
        Fmt.countdown(_remaining),
        style: (widget.style ?? context.type.countdown).copyWith(
          color: colors.urgencyForeground(_effectiveUrgency),
        ),
      ),
    );
  }
}
