import 'dart:async';

import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/domain/pickup_window.dart';
import 'package:surplus_marketplace/design_system/components/countdown_text.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// The cart-hold countdown banner (§5c.1), prominent and persistent —
/// escalates to a critical treatment inside the last 2 minutes, and
/// freezes (A2) once payment enters flight.
///
/// A small ticking timer of its own, separate from [CountdownText]'s
/// internal one: the banner's *background colour* must escalate at the
/// 2-minute mark, which is a different threshold from [CountdownText]'s
/// own 30-minute `closingSoon` default (tuned for pickup windows, not a
/// ~9-minute hold) — passing an explicit `urgency` derived here is what
/// lets the existing component's colour mapping stay correct for this
/// much shorter countdown.
class HoldCountdownBanner extends StatefulWidget {
  const HoldCountdownBanner({
    required this.expiresAt,
    required this.clock,
    required this.label,
    this.frozen = false,
    this.frozenLabel,
    this.onExpired,
    super.key,
  });

  static const escalateThreshold = Duration(minutes: 2);

  final DateTime expiresAt;
  final Clock clock;
  final String label;
  final VoidCallback? onExpired;
  final bool frozen;
  final String? frozenLabel;

  @override
  State<HoldCountdownBanner> createState() => _HoldCountdownBannerState();
}

class _HoldCountdownBannerState extends State<HoldCountdownBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(HoldCountdownBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt ||
        oldWidget.frozen != widget.frozen) {
      _schedule();
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (widget.frozen) return;
    final remaining = widget.expiresAt.difference(widget.clock.now());
    final interval = remaining <= HoldCountdownBanner.escalateThreshold
        ? const Duration(seconds: 1)
        : const Duration(seconds: 20);
    _timer = Timer.periodic(interval, (_) {
      if (!mounted) return;
      setState(() {});
      final nowRemaining = widget.expiresAt.difference(widget.clock.now());
      if (nowRemaining <= HoldCountdownBanner.escalateThreshold &&
          interval.inSeconds != 1) {
        _schedule();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final remaining = widget.expiresAt.difference(widget.clock.now());
    final escalated =
        !widget.frozen && remaining <= HoldCountdownBanner.escalateThreshold;

    final palette = widget.frozen
        ? colors.info
        : (escalated ? colors.critical : colors.info);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Space.x4,
        vertical: Space.x3,
      ),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 20, color: palette.fg),
          const SizedBox(width: Space.x2),
          Expanded(
            child: Text(
              widget.label,
              style: context.type.body.copyWith(color: palette.fg),
            ),
          ),
          CountdownText(
            target: widget.expiresAt,
            clock: widget.clock,
            urgency: escalated
                ? WindowUrgency.closingSoon
                : WindowUrgency.upcoming,
            frozen: widget.frozen,
            frozenLabel: widget.frozenLabel,
            announceThresholds: CountdownText.holdThresholds,
            onExpired: widget.onExpired,
            style: context.type.countdown.copyWith(color: palette.fg),
          ),
        ],
      ),
    );
  }
}
