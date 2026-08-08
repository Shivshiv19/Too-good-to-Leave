import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/core/utils/formatters.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/orders/orders.dart';

/// §5d.5 — a dialog, not a route (§4.6). Shows the money consequence
/// **before** the user commits, and the confirming button states the
/// outcome rather than a bare "Confirm" (§5d.5's own requirement for any
/// destructive financial action).
///
/// Returns `true` once the order has actually been cancelled.
Future<bool> showCancelOrderDialog(
  BuildContext context, {
  required String orderId,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _CancelOrderDialog(orderId: orderId),
  );
  return result ?? false;
}

enum _Phase { loading, ready, submitting, notAllowed, error }

class _CancelOrderDialog extends ConsumerStatefulWidget {
  const _CancelOrderDialog({required this.orderId});

  final String orderId;

  @override
  ConsumerState<_CancelOrderDialog> createState() => _CancelOrderDialogState();
}

class _CancelOrderDialogState extends ConsumerState<_CancelOrderDialog> {
  _Phase _phase = _Phase.loading;
  CancellationEligibility? _eligibility;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final eligibility = await ref
          .read(ordersRepositoryProvider)
          .getCancellationEligibility(widget.orderId);
      if (!mounted) return;
      setState(() {
        _eligibility = eligibility;
        _phase = eligibility.eligible ? _Phase.ready : _Phase.notAllowed;
      });
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _announceConsequence(),
      );
    } on Object {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  void _announceConsequence() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final eligibility = _eligibility;
    if (eligibility == null) return;
    // §5d.5 — the consequence sentence is announced first, before the
    // buttons become reachable.
    final message = eligibility.eligible
        ? l10n.cancelOrderFullRefund(Fmt.money(eligibility.refundAmount))
        : l10n.cancellationTooLateBody(Fmt.timeOfDay(eligibility.cutoffAt));
    SemanticsService.announce(message, Directionality.of(context));
  }

  Future<void> _confirm() async {
    setState(() => _phase = _Phase.submitting);
    try {
      await ref.read(ordersRepositoryProvider).cancelOrder(widget.orderId);
      if (mounted) Navigator.of(context).pop(true);
    } on CancellationWindowPassedException {
      if (mounted) setState(() => _phase = _Phase.notAllowed);
    } on Object {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final eligibility = _eligibility;

    if (_phase == _Phase.loading) {
      return const Dialog(
        child: Padding(
          padding: EdgeInsets.all(Space.x8),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_phase == _Phase.error) {
      return AlertDialog(
        title: Text(l10n.errorServerTitle),
        content: Text(l10n.errorServerBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.close),
          ),
          TextButton(onPressed: _load, child: Text(l10n.errorRetry)),
        ],
      );
    }

    if (_phase == _Phase.notAllowed || eligibility == null) {
      return AlertDialog(
        title: Text(l10n.cancellationTooLateTitle),
        content: Text(
          l10n.cancellationTooLateBody(
            Fmt.timeOfDay(eligibility?.cutoffAt ?? DateTime.now()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.close),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text(l10n.cancelOrderTitle),
      content: Text(
        l10n.cancelOrderFullRefund(Fmt.money(eligibility.refundAmount)),
        style: TextStyle(color: colors.success.fg, fontWeight: FontWeight.w600),
      ),
      actions: [
        TextButton(
          onPressed: _phase == _Phase.submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancelOrderKeep),
        ),
        AppButton(
          label: l10n.cancelOrderConfirmWithRefund(
            Fmt.money(eligibility.refundAmount),
          ),
          variant: AppButtonVariant.destructive,
          expand: false,
          isLoading: _phase == _Phase.submitting,
          onPressed: _phase == _Phase.submitting ? null : _confirm,
        ),
      ],
    );
  }
}
