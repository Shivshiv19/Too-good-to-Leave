import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/core/utils/formatters.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/components/refund_timeline.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/checkout/checkout.dart';
import 'package:surplus_marketplace/features/orders/orders.dart';
import 'package:surplus_marketplace/features/orders/presentation/utils/payment_method_label.dart';

enum _Phase { loading, loaded, notFound, error }

/// §4.2 `/orders/:orderId/refund`, §5d.4 — makes money-in-transit visible
/// and believable.
class RefundStatusScreen extends ConsumerStatefulWidget {
  const RefundStatusScreen({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<RefundStatusScreen> createState() => _RefundStatusScreenState();
}

class _RefundStatusScreenState extends ConsumerState<RefundStatusScreen> {
  _Phase _phase = _Phase.loading;
  RefundDetail? _refund;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _phase = _Phase.loading);
    try {
      final refund = await ref
          .read(ordersRepositoryProvider)
          .getRefund(widget.orderId);
      if (!mounted) return;
      setState(() {
        _refund = refund;
        _phase = _Phase.loaded;
      });
    } on NotFoundException {
      if (mounted) setState(() => _phase = _Phase.notFound);
    } on Object {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(backgroundColor: colors.surfaceBase, elevation: 0),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.loading => const Center(child: CircularProgressIndicator()),
          _Phase.notFound => _Message(
            title: l10n.notFoundTitle,
            body: l10n.notFoundBody,
          ),
          _Phase.error => _ErrorState(onRetry: _load, l10n: l10n),
          _Phase.loaded => _Loaded(refund: _refund!, l10n: l10n),
        },
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.refund, required this.l10n});

  final RefundDetail refund;
  final AppLocalizations l10n;

  String _stepLabel(RefundStepLabel label) => switch (label) {
    RefundStepLabel.started => l10n.refundStepStarted,
    RefundStepLabel.sentToBank => l10n.refundStepSentToBank,
    RefundStepLabel.credited => l10n.refundStepCredited,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (refund.status == RefundStatus.failed) {
      return _Message(
        title: l10n.refundFailedTitle,
        body: l10n.refundFailedBody(
          Fmt.expectedBy(refund.expectedByAt ?? DateTime.now()),
        ),
      );
    }

    final steps = refund.steps
        .map(
          (s) => RefundTimelineStep(
            label: _stepLabel(s.label),
            completed: s.completedAt != null,
            timestamp: s.completedAt != null
                ? Fmt.absoluteTime(s.completedAt!, const SystemClock())
                : null,
          ),
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.all(Space.x4),
      children: [
        Semantics(
          label: 'Refund amount ${Fmt.money(refund.amount)}',
          excludeSemantics: true,
          child: Text(
            Fmt.money(refund.amount),
            style: context.type.display,
          ),
        ),
        const SizedBox(height: Space.x2),
        if (refund.expectedByAt != null)
          Text(
            l10n.refundExpectedBy(
              Fmt.expectedBy(refund.expectedByAt!),
              3,
              7,
            ),
            style: context.type.body.copyWith(color: colors.textSecondary),
          ),
        const SizedBox(height: Space.x6),
        RefundTimeline(
          steps: steps,
          semanticLabelFor: (step, i) => l10n.refundStepSemantic(
            i + 1,
            steps.length,
            step.label,
            step.completed ? (step.timestamp ?? '') : 'pending',
          ),
        ),
        const SizedBox(height: Space.x4),
        Text(
          l10n.refundDestination(
            paymentMethodLabel(refund.method, l10n),
            refund.maskedDestination,
          ),
          style: context.type.body,
        ),
        if (refund.bankReferenceNumber != null) ...[
          const SizedBox(height: Space.x2),
          Text(
            l10n.refundBankReference,
            style: context.type.caption.copyWith(color: colors.textSecondary),
          ),
          Semantics(
            label: refund.bankReferenceNumber!.split('').join(' '),
            excludeSemantics: true,
            child: Text(
              refund.bankReferenceNumber!,
              style: context.type.codeMono,
            ),
          ),
        ],
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: context.type.display,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.x2),
            Text(
              body,
              style: context.type.body.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry, required this.l10n});

  final Future<void> Function() onRetry;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.errorServerTitle,
              style: context.type.display,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.x2),
            Text(
              l10n.errorServerBody,
              style: context.type.body.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.x6),
            AppButton(label: l10n.errorRetry, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
