import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:surplus_marketplace/app/router/routes.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/core/utils/formatters.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/design_system/foundations/motion.dart';
import 'package:surplus_marketplace/features/checkout/domain/entities/order.dart';
import 'package:surplus_marketplace/features/checkout/presentation/providers/checkout_providers.dart';

/// §4.2 `/checkout/confirmed/:orderId`, §5c.8 — delivers relief, then
/// orients the user toward the pickup they've just committed to.
///
/// **Tone: calm and premium, not a confetti burst** — the user spent money
/// on discounted surplus food; over-celebration reads as overcompensation.
class ConfirmedScreen extends ConsumerStatefulWidget {
  const ConfirmedScreen({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<ConfirmedScreen> createState() => _ConfirmedScreenState();
}

class _ConfirmedScreenState extends ConsumerState<ConfirmedScreen> {
  static const _clock = SystemClock();

  Order? _order;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _announceSuccess());
    _load();
  }

  Future<void> _load() async {
    try {
      final order = await ref
          .read(checkoutRepositoryProvider)
          .getOrder(widget.orderId);
      if (mounted) setState(() => _order = order);
    } on Object {
      // §5c.8 — an order-fetch failure must still show success; the
      // payment already succeeded and is not contingent on this read.
      // With no order to render, this screen has nothing left to degrade
      // to, so it stays on its loading state rather than a false error.
    }
  }

  void _announceSuccess() {
    final l10n = AppLocalizations.of(context);
    SemanticsService.announce(
      l10n.confirmedTitle,
      Directionality.of(context),
      assertiveness: Assertiveness.assertive,
    );
  }

  Future<void> _addToCalendar(Order order) async {
    final l10n = AppLocalizations.of(context);
    try {
      final ics = _buildIcs(order);
      final file = XFile.fromData(
        Uint8List.fromList(utf8.encode(ics)),
        name: '${order.orderCode}.ics',
        mimeType: 'text/calendar',
      );
      // The replacement (SharePlus.instance.share) needs a ShareParams
      // object with the same file list; shareXFiles is the simpler call
      // for this single-file case and remains supported.
      // ignore: deprecated_member_use
      await Share.shareXFiles([file], subject: order.orderCode);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.calendarAdded)));
      }
    } on Object {
      // Best-effort — calendar hand-off support varies by platform/browser;
      // never block the confirmation flow on it.
    }
  }

  String _buildIcs(Order order) {
    String stamp(DateTime d) =>
        '${d.toUtc().toIso8601String().replaceAll(RegExp('[-:]'), '').split('.').first}Z';
    return [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'BEGIN:VEVENT',
      'UID:${order.id}@surplusmarketplace',
      'DTSTART:${stamp(order.pickupWindow.startAt)}',
      'DTEND:${stamp(order.pickupWindow.endAt)}',
      'SUMMARY:Collect your reservation — ${order.merchantSnapshot.displayName}',
      'LOCATION:${order.merchantSnapshot.address.displayLine}',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final order = _order;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      body: SafeArea(
        child: order == null
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(Space.x6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: Space.x8),
                    Center(
                      child: context.prefersReducedMotion
                          ? Icon(
                              Icons.check_circle,
                              size: 64,
                              color: colors.success.fg,
                            )
                          : TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: Motion.standard,
                              builder: (context, value, child) => Opacity(
                                opacity: value,
                                child: Icon(
                                  Icons.check_circle,
                                  size: 64,
                                  color: colors.success.fg,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: Space.x4),
                    Text(
                      l10n.confirmedTitle,
                      style: context.type.display,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Space.x6),
                    Center(
                      child: Column(
                        children: [
                          Text(
                            l10n.confirmedOrderCode,
                            style: context.type.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          Semantics(
                            label: order.orderCode.split('').join(' '),
                            excludeSemantics: true,
                            child: Text(
                              order.orderCode,
                              style: context.type.title.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.x6),
                    Container(
                      padding: const EdgeInsets.all(Space.x4),
                      decoration: BoxDecoration(
                        color: colors.surfaceRaised,
                        borderRadius: BorderRadius.circular(Radii.card),
                        border: Border.all(color: colors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            label: Fmt.pickupWindow(order.pickupWindow, _clock),
                            excludeSemantics: true,
                            child: Text(
                              Fmt.pickupWindow(order.pickupWindow, _clock),
                              style: context.type.title,
                            ),
                          ),
                          const SizedBox(height: Space.x2),
                          Text(
                            order.merchantSnapshot.displayName,
                            style: context.type.body,
                          ),
                          Text(
                            order.merchantSnapshot.address.displayLine,
                            style: context.type.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.x4),
                    AppButton(
                      label: l10n.confirmedAddToCalendar,
                      variant: AppButtonVariant.secondary,
                      icon: Icons.calendar_today_outlined,
                      onPressed: () => _addToCalendar(order),
                    ),
                    const SizedBox(height: Space.x6),
                    AppButton(
                      label: l10n.confirmedViewPickup,
                      onPressed: () => CheckoutNotifyPrimerRoute(
                        orderId: order.id,
                      ).go(context),
                    ),
                    const SizedBox(height: Space.x3),
                    AppButton(
                      label: l10n.confirmedBackToDiscover,
                      variant: AppButtonVariant.tertiary,
                      onPressed: () => const DiscoverRoute().go(context),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
