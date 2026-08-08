import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:surplus_marketplace/app/router/routes.dart';
import 'package:surplus_marketplace/app/session/session_providers.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/components/blocker_list.dart';
import 'package:surplus_marketplace/design_system/components/otp_code_field.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/account/account.dart';
import 'package:surplus_marketplace/features/auth/auth.dart';

enum _Phase {
  checkingBlockers,
  eligible,
  blocked,
  confirming,
  verifying,
  submitting,
  deleted,
  error,
}

/// §4.2 `/account/delete`, §5f.11, amendment A20. The screen with the most
/// substance in Account — deletion collides with obligations that cannot
/// be waived.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  _Phase _phase = _Phase.checkingBlockers;
  DeletionEligibility? _eligibility;
  String? _otpRequestId;
  final _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _phase = _Phase.checkingBlockers);
    try {
      final eligibility = await ref
          .read(accountRepositoryProvider)
          .getDeletionEligibility();
      if (!mounted) return;
      setState(() {
        _eligibility = eligibility;
        _phase = eligibility.eligible ? _Phase.eligible : _Phase.blocked;
      });
      if (!eligibility.eligible) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            SemanticsService.announce(
              AppLocalizations.of(context).deletionBlockedTitle,
              Directionality.of(context),
              assertiveness: Assertiveness.assertive,
            );
          }
        });
      }
    } on Object {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  Future<void> _startConfirm() async {
    setState(() => _phase = _Phase.confirming);
    try {
      final request = await ref
          .read(authRepositoryProvider)
          .requestReverificationOtp();
      if (mounted) {
        setState(() {
          _otpRequestId = request.requestId;
          _phase = _Phase.verifying;
        });
      }
    } on Object {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  Future<void> _verifyAndDelete(String code) async {
    final requestId = _otpRequestId;
    if (requestId == null) return;
    setState(() => _phase = _Phase.submitting);
    try {
      await ref
          .read(authRepositoryProvider)
          .verifyReverificationOtp(
            requestId: requestId,
            code: code,
          );
      await ref.read(accountRepositoryProvider).deleteAccount();
      if (!mounted) return;
      ref.read(sessionStateProvider).markSignedOut();
      setState(() => _phase = _Phase.deleted);
    } on OtpInvalidException {
      if (mounted) {
        setState(() => _phase = _Phase.verifying);
        _otpController.clear();
      }
    } on AccountDeletionBlockedException catch (e) {
      if (mounted) {
        setState(() {
          _eligibility = DeletionEligibility(
            eligible: false,
            blockers: e.blockers,
          );
          _phase = _Phase.blocked;
        });
      }
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
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        elevation: 0,
        title: Text(l10n.accountDeleteAccount),
      ),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.checkingBlockers => const Center(
            child: CircularProgressIndicator(),
          ),
          _Phase.error => Center(child: Text(l10n.errorServerBody)),
          _Phase.deleted => _Deleted(l10n: l10n),
          _Phase.blocked => _Blocked(
            eligibility: _eligibility!,
            l10n: l10n,
          ),
          _Phase.eligible => _Eligible(onConfirm: _startConfirm, l10n: l10n),
          _Phase.confirming => const Center(child: CircularProgressIndicator()),
          _Phase.verifying || _Phase.submitting => _Verify(
            controller: _otpController,
            submitting: _phase == _Phase.submitting,
            onCompleted: _verifyAndDelete,
            l10n: l10n,
          ),
        },
      ),
    );
  }
}

class _Eligible extends StatelessWidget {
  const _Eligible({required this.onConfirm, required this.l10n});

  final VoidCallback onConfirm;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsets.all(Space.x4),
      children: [
        // §5f.11 — the retained-data explanation appears in the semantic
        // tree BEFORE the confirm action, so it can't be skipped.
        Text(
          l10n.deletionRetainedNotice,
          style: context.type.body.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: Space.x2),
        Text(
          l10n.deletionGracePeriod,
          style: context.type.body.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: Space.x6),
        AppButton(
          label: l10n.deletionConfirmCta,
          variant: AppButtonVariant.destructive,
          onPressed: onConfirm,
        ),
      ],
    );
  }
}

class _Blocked extends StatelessWidget {
  const _Blocked({required this.eligibility, required this.l10n});

  final DeletionEligibility eligibility;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Space.x4),
      children: [
        Semantics(
          liveRegion: true,
          child: Text(l10n.deletionBlockedTitle, style: context.type.title),
        ),
        const SizedBox(height: Space.x4),
        BlockerList(
          blockers: [
            for (final blocker in eligibility.blockers)
              BlockerItem(
                label: blocker.kind == DeletionBlockerKind.activeOrder
                    ? l10n.deletionBlockedActiveOrder
                    : l10n.deletionBlockedPendingRefund,
                actionLabel: l10n.deletionBlockedResolve,
                onTap: () => OrderDetailRoute(
                  orderId: blocker.orderId,
                ).push<void>(context),
              ),
          ],
        ),
      ],
    );
  }
}

class _Verify extends StatelessWidget {
  const _Verify({
    required this.controller,
    required this.submitting,
    required this.onCompleted,
    required this.l10n,
  });

  final TextEditingController controller;
  final bool submitting;
  final ValueChanged<String> onCompleted;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.all(Space.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.deletionOtpTitle, style: context.type.title),
          const SizedBox(height: Space.x2),
          Text(
            l10n.deletionOtpBody,
            style: context.type.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: Space.x6),
          OtpCodeField(
            length: 6,
            controller: controller,
            semanticLabel: l10n.deletionOtpTitle,
            autofocus: true,
            onCompleted: submitting ? null : onCompleted,
          ),
          if (submitting) ...[
            const SizedBox(height: Space.x4),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}

class _Deleted extends StatelessWidget {
  const _Deleted({required this.l10n});

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
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: colors.success.fg,
            ),
            const SizedBox(height: Space.x4),
            Text(
              l10n.deletionDoneTitle,
              style: context.type.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.x2),
            Text(
              l10n.deletionGracePeriod,
              style: context.type.body.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.x6),
            AppButton(
              label: l10n.back,
              onPressed: () => const DiscoverRoute().go(context),
            ),
          ],
        ),
      ),
    );
  }
}
