import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:surplus_marketplace/app/router/routes.dart';
import 'package:surplus_marketplace/app/session/session_providers.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/core/utils/formatters.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/checkout/domain/entities/order.dart';
import 'package:surplus_marketplace/features/checkout/domain/entities/payment_status.dart';
import 'package:surplus_marketplace/features/checkout/presentation/providers/checkout_providers.dart';

/// §4.2 `/checkout/verifying?orderId=`, §5c.6 — resolves payment ambiguity
/// **without the user paying twice.** The single most consequential screen
/// in the application.
///
/// **R3.** Only the repository's `verifyPayment` (the server-equivalent)
/// ever determines the outcome here — never a gateway callback, never a
/// client guess.
class VerifyingScreen extends ConsumerStatefulWidget {
  const VerifyingScreen({
    required this.orderId,
    this.resumed = false,
    super.key,
  });

  final String orderId;

  /// True only when reached via §4.3 rule 4 (A3's cold-start resume) —
  /// distinct from ordinary navigation from `/checkout/processing`.
  final bool resumed;

  @override
  ConsumerState<VerifyingScreen> createState() => _VerifyingScreenState();
}

class _VerifyingScreenState extends ConsumerState<VerifyingScreen> {
  static const _slowThreshold = Duration(seconds: 30);
  static const _giveUpAfter = Duration(minutes: 5);
  static const _backoff = [
    Duration(seconds: 2),
    Duration(seconds: 3),
    Duration(seconds: 5),
    Duration(seconds: 8),
    Duration(seconds: 13),
  ];
  static const _steadyInterval = Duration(seconds: 15);

  Order? _order;
  bool _slow = false;
  bool _leftPending = false;
  bool _settled = false;
  Timer? _pollTimer;
  final _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _announceInstruction());
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _announceInstruction() {
    final l10n = AppLocalizations.of(context);
    // §5c.6 — the most important copy in the app, announced assertively.
    // A polite live region would queue behind the headline and could be
    // missed entirely.
    SemanticsService.announce(
      l10n.verifyingInstruction,
      Directionality.of(context),
      assertiveness: Assertiveness.assertive,
    );
  }

  Future<void> _load() async {
    try {
      final order = await ref
          .read(checkoutRepositoryProvider)
          .getOrder(widget.orderId);
      if (!mounted) return;
      setState(() => _order = order);
      _pollAt(0);
    } on Object {
      // §5c.6 — never imply the money is lost, even on an unreachable
      // server; keep retrying rather than surfacing a dead end.
      _pollTimer = Timer(_backoff.first, () => _load());
    }
  }

  void _pollAt(int step) {
    if (_settled || !mounted) return;
    if (_stopwatch.elapsed >= _giveUpAfter) {
      setState(() => _leftPending = true);
      return;
    }
    if (_stopwatch.elapsed >= _slowThreshold && !_slow) {
      setState(() => _slow = true);
    }
    final delay = step < _backoff.length ? _backoff[step] : _steadyInterval;
    _pollTimer = Timer(delay, () => _verify(step));
  }

  Future<void> _verify(int step) async {
    final order = _order;
    if (order == null || _settled || !mounted) return;
    try {
      final payment = await ref
          .read(checkoutRepositoryProvider)
          .verifyPayment(order.payment.id);
      if (!mounted) return;
      switch (payment.status) {
        case PaymentStatus.captured:
          _settled = true;
          ref.read(sessionStateProvider).clearUnresolvedPayment();
          CheckoutConfirmedRoute(orderId: order.id).go(context);
        case PaymentStatus.failed:
        case PaymentStatus.cancelled:
          _settled = true;
          ref.read(sessionStateProvider).clearUnresolvedPayment();
          CheckoutFailedRoute(orderId: order.id).go(context);
        case PaymentStatus.pending:
        case PaymentStatus.pendingVerification:
        case PaymentStatus.refundInitiated:
        case PaymentStatus.refunded:
        case PaymentStatus.refundFailed:
        case PaymentStatus.created:
          _pollAt(step + 1);
      }
    } on Object {
      _pollAt(step + 1);
    }
  }

  Future<void> _confirmLeave() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.verifyingLeaveTitle),
        content: Text(l10n.verifyingLeaveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.verifyingLeaveConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      _settled = true;
      const DiscoverRoute().go(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final order = _order;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: colors.surfaceBase,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(Space.x6),
              child: order == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: Space.x6),
                        Text(
                          l10n.verifyingTitle,
                          style: context.type.title,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: Space.x4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(Space.x4),
                          decoration: BoxDecoration(
                            color: colors.attention.bg,
                            borderRadius: BorderRadius.circular(Radii.card),
                          ),
                          child: Text(
                            l10n.verifyingInstruction,
                            style: context.type.body.copyWith(
                              color: colors.attention.fg,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: Space.x4),
                        Text(
                          '${order.merchantSnapshot.displayName} · '
                          '${Fmt.money(order.breakdown.total)}',
                          style: context.type.body.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: Space.x2),
                        Text(
                          l10n.verifyingReassurance,
                          style: context.type.body.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        if (widget.resumed) ...[
                          const SizedBox(height: Space.x2),
                          Text(
                            l10n.verifyingColdStart,
                            style: context.type.caption.copyWith(
                              color: colors.textTertiary,
                            ),
                          ),
                        ],
                        if (_slow) ...[
                          const SizedBox(height: Space.x6),
                          Text(
                            _leftPending
                                ? l10n.verifyingLeaveBody
                                : l10n.verifyingSlow(5),
                            style: context.type.body.copyWith(
                              color: colors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (!_leftPending) ...[
                            const SizedBox(height: Space.x4),
                            AppButton(
                              label: l10n.verifyingNotifyMe,
                              variant: AppButtonVariant.secondary,
                              onPressed: _confirmLeave,
                            ),
                          ],
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
