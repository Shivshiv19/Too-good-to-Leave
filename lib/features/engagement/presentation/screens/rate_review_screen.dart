import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:surplus_marketplace/app/router/routes.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/core/utils/formatters.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/components/escalation_bridge.dart';
import 'package:surplus_marketplace/design_system/components/facet_chip.dart';
import 'package:surplus_marketplace/design_system/components/inline_confirmation.dart';
import 'package:surplus_marketplace/design_system/components/star_rating_input.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/design_system/foundations/motion.dart';
import 'package:surplus_marketplace/features/auth/auth.dart';
import 'package:surplus_marketplace/features/checkout/checkout.dart';
import 'package:surplus_marketplace/features/engagement/engagement.dart';
import 'package:surplus_marketplace/features/orders/orders.dart';

enum _Phase {
  loading,
  idle,
  submitting,
  submitted,
  alreadyReviewed,
  notEligible,
  error,
}

final _contactInfoPattern = RegExp(r'\d{7,}|[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}');

/// §4.2 `/orders/:orderId/review`, §5e.3. Owned by `engagement` despite its
/// path — the same "declared in more than one branch" shape as the bag
/// detail route (§4-navigation-flow.md).
class RateReviewScreen extends ConsumerStatefulWidget {
  const RateReviewScreen({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<RateReviewScreen> createState() => _RateReviewScreenState();
}

class _RateReviewScreenState extends ConsumerState<RateReviewScreen> {
  _Phase _phase = _Phase.loading;
  Order? _order;
  Review? _existingReview;
  int _rating = 0;
  final _tags = <ReviewTag>{};
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final order = await ref
          .read(ordersRepositoryProvider)
          .getOrder(widget.orderId);
      final existing = await ref
          .read(engagementRepositoryProvider)
          .getExistingReview(widget.orderId);
      if (!mounted) return;
      if (existing != null) {
        setState(() {
          _order = order;
          _existingReview = existing;
          _phase = _Phase.alreadyReviewed;
        });
        return;
      }
      if (order.status != OrderStatus.collected) {
        setState(() {
          _order = order;
          _phase = _Phase.notEligible;
        });
        return;
      }
      setState(() {
        _order = order;
        _phase = _Phase.idle;
      });
    } on Object {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  bool get _showEscalation =>
      (_rating > 0 && _rating <= 2) || _tags.contains(ReviewTag.notFresh);

  Future<void> _submit({bool alsoCreateIssue = false}) async {
    final l10n = AppLocalizations.of(context);
    if (_rating == 0) {
      SemanticsService.announce(
        l10n.reviewRatingRequired,
        Directionality.of(context),
      );
      return;
    }
    setState(() => _phase = _Phase.submitting);
    try {
      final customer = await ref.read(authRepositoryProvider).restoreSession();
      await ref
          .read(engagementRepositoryProvider)
          .submitReview(
            orderId: widget.orderId,
            customerId: customer!.id,
            rating: _rating,
            tags: _tags.toList(),
            comment: _commentController.text.trim().isEmpty
                ? null
                : _commentController.text.trim(),
            alsoCreateIssue: alsoCreateIssue,
          );
      if (!mounted) return;
      setState(() => _phase = _Phase.submitted);
      SemanticsService.announce(
        l10n.reviewSubmittedTitle,
        Directionality.of(context),
      );
      Future<void>.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) OrderDetailRoute(orderId: widget.orderId).go(context);
      });
    } on Object {
      if (mounted) setState(() => _phase = _Phase.idle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final order = _order;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        elevation: 0,
        title: Text(l10n.reviewTitle),
      ),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.loading => const Center(child: CircularProgressIndicator()),
          _Phase.error => _Message(
            title: l10n.errorServerTitle,
            body: l10n.errorServerBody,
          ),
          _Phase.notEligible => _Message(
            title: l10n.reviewNotYetEligible,
            body: '',
            action: AppButton(
              label: l10n.back,
              onPressed: () =>
                  OrderDetailRoute(orderId: widget.orderId).go(context),
            ),
          ),
          _Phase.alreadyReviewed =>
            order == null
                ? const SizedBox.shrink()
                : _AlreadyReviewed(
                    review: _existingReview!,
                    order: order,
                    l10n: l10n,
                  ),
          _Phase.submitted =>
            order == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.all(Space.x4),
                    child: InlineConfirmation(
                      title: l10n.reviewSubmittedTitle,
                      body: l10n.reviewSubmittedBody(
                        order.merchantSnapshot.displayName,
                      ),
                      reducedMotion: context.prefersReducedMotion,
                    ),
                  ),
          _Phase.idle || _Phase.submitting =>
            order == null
                ? const SizedBox.shrink()
                : _Form(
                    order: order,
                    rating: _rating,
                    onRatingChanged: (v) => setState(() => _rating = v),
                    tags: _tags,
                    onToggleTag: (t) => setState(
                      () => _tags.contains(t) ? _tags.remove(t) : _tags.add(t),
                    ),
                    commentController: _commentController,
                    showEscalation: _showEscalation,
                    submitting: _phase == _Phase.submitting,
                    onSubmit: () => _submit(),
                    onSubmitWithIssue: () => _submit(alsoCreateIssue: true),
                    l10n: l10n,
                  ),
        },
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.order,
    required this.rating,
    required this.onRatingChanged,
    required this.tags,
    required this.onToggleTag,
    required this.commentController,
    required this.showEscalation,
    required this.submitting,
    required this.onSubmit,
    required this.onSubmitWithIssue,
    required this.l10n,
  });

  final Order order;
  final int rating;
  final ValueChanged<int> onRatingChanged;
  final Set<ReviewTag> tags;
  final ValueChanged<ReviewTag> onToggleTag;
  final TextEditingController commentController;
  final bool showEscalation;
  final bool submitting;
  final VoidCallback onSubmit;
  final VoidCallback onSubmitWithIssue;
  final AppLocalizations l10n;

  String _tagLabel(ReviewTag tag) => switch (tag) {
    ReviewTag.greatValue => l10n.reviewTagGreatValue,
    ReviewTag.fresh => l10n.reviewTagFresh,
    ReviewTag.generousPortion => l10n.reviewTagGenerous,
    ReviewTag.easyPickup => l10n.reviewTagEasyPickup,
    ReviewTag.friendlyStaff => l10n.reviewTagFriendlyStaff,
    ReviewTag.notFresh => l10n.reviewTagNotFresh,
    ReviewTag.tooLittle => l10n.reviewTagTooLittle,
    ReviewTag.hardToFind => l10n.reviewTagHardToFind,
    ReviewTag.longWait => l10n.reviewTagLongWait,
    ReviewTag.notAsDescribed => l10n.reviewTagNotAsDescribed,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tagSet = rating > 0 && rating <= 3
        ? ReviewTag.values.where((t) => t.isNegative)
        : ReviewTag.values.where((t) => !t.isNegative);
    final showContactWarning = _contactInfoPattern.hasMatch(
      commentController.text,
    );

    return ListView(
      padding: const EdgeInsets.all(Space.x4),
      children: [
        Text(order.merchantSnapshot.displayName, style: context.type.title),
        Text(
          '${order.bagSnapshot.title} · ${Fmt.pickupWindow(order.pickupWindow, const SystemClock())}',
          style: context.type.caption.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: Space.x6),
        StarRatingInput(
          value: rating,
          onChanged: onRatingChanged,
          semanticLabelFor: (s) => l10n.reviewRatingSemantic(s),
        ),
        const SizedBox(height: Space.x6),
        if (rating > 0)
          Wrap(
            spacing: Space.x2,
            runSpacing: Space.x2,
            children: [
              for (final tag in tagSet)
                FacetChip(
                  label: _tagLabel(tag),
                  active: tags.contains(tag),
                  onTap: () => onToggleTag(tag),
                ),
            ],
          ),
        const SizedBox(height: Space.x6),
        TextField(
          controller: commentController,
          maxLength: 500,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: l10n.reviewCommentLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        if (showContactWarning)
          Padding(
            padding: const EdgeInsets.only(top: Space.x1),
            child: Text(
              l10n.reviewContactWarning,
              style: context.type.caption.copyWith(color: colors.attention.fg),
            ),
          ),
        if (showEscalation) ...[
          const SizedBox(height: Space.x4),
          EscalationBridge(
            prompt: l10n.reviewEscalationPrompt,
            actionLabel: l10n.orderActionReportIssue,
            onAction: () =>
                OrderIssueRoute(orderId: order.id).push<void>(context),
          ),
        ],
        const SizedBox(height: Space.x6),
        AppButton(
          label: l10n.reviewSubmitCta,
          isLoading: submitting,
          onPressed: rating == 0 || submitting ? null : onSubmit,
          disabledReason: rating == 0 ? l10n.reviewRatingRequired : null,
        ),
      ],
    );
  }
}

class _AlreadyReviewed extends StatelessWidget {
  const _AlreadyReviewed({
    required this.review,
    required this.order,
    required this.l10n,
  });

  final Review review;
  final Order order;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsets.all(Space.x4),
      children: [
        Text(l10n.reviewAlreadyExists, style: context.type.title),
        const SizedBox(height: Space.x4),
        StarRatingInput(
          value: review.rating,
          onChanged: (_) {},
          semanticLabelFor: (s) => l10n.reviewRatingSemantic(review.rating),
        ),
        if (review.comment != null) ...[
          const SizedBox(height: Space.x4),
          Text(
            review.comment!,
            style: context.type.body.copyWith(color: colors.textSecondary),
          ),
        ],
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.body, this.action});

  final String title;
  final String body;
  final Widget? action;

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
            if (body.isNotEmpty) ...[
              const SizedBox(height: Space.x2),
              Text(
                body,
                style: context.type.body.copyWith(color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: Space.x6), action!],
          ],
        ),
      ),
    );
  }
}
