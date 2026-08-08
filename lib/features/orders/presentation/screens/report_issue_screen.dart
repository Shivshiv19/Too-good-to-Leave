import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:surplus_marketplace/app/router/routes.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/design_system/components/advisory_block.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/components/photo_attachment_row.dart';
import 'package:surplus_marketplace/design_system/components/selectable_card.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/checkout/checkout.dart';
import 'package:surplus_marketplace/features/orders/orders.dart';

enum _Phase { loading, idle, submitting, submitted, error, notFound }

/// §4.2 `/orders/:orderId/issue`, §5d.6 — self-serve resolution of the top
/// support drivers, **scoped to the order's own status**.
class ReportIssueScreen extends ConsumerStatefulWidget {
  const ReportIssueScreen({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends ConsumerState<ReportIssueScreen> {
  _Phase _phase = _Phase.loading;
  Order? _order;
  IssueType? _selectedType;
  final _descriptionController = TextEditingController();
  final _photos = <PhotoAttachment>[];
  IssueReport? _report;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final order = await ref
          .read(ordersRepositoryProvider)
          .getOrder(widget.orderId);
      if (mounted) {
        setState(() {
          _order = order;
          _phase = _Phase.idle;
        });
      }
    } on NotFoundException {
      if (mounted) setState(() => _phase = _Phase.notFound);
    } on Object {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  List<IssueType> _typesFor(OrderStatus status) => switch (status) {
    OrderStatus.confirmed || OrderStatus.readyForPickup => const [
      IssueType.merchantClosed,
      IssueType.noBagReady,
      IssueType.wrongLocation,
      IssueType.cantMakeIt,
    ],
    OrderStatus.collected => const [
      IssueType.notAsDescribed,
      IssueType.qualityProblem,
      IssueType.quantityWrong,
      IssueType.foodSafety,
    ],
    OrderStatus.expiredUncollected => const [
      IssueType.wasThereCouldntCollect,
      IssueType.merchantRefused,
    ],
    _ => const [],
  };

  String _typeLabel(IssueType type, AppLocalizations l10n) => switch (type) {
    IssueType.merchantClosed => l10n.issueTypeMerchantClosed,
    IssueType.noBagReady => l10n.issueTypeNoBagReady,
    IssueType.wrongLocation => l10n.issueTypeWrongLocation,
    IssueType.cantMakeIt => l10n.issueTypeCantMakeIt,
    IssueType.notAsDescribed => l10n.issueTypeNotAsDescribed,
    IssueType.qualityProblem => l10n.issueTypeQuality,
    IssueType.quantityWrong => l10n.issueTypeQuantityWrong,
    IssueType.foodSafety => l10n.issueTypeFoodSafety,
    IssueType.wasThereCouldntCollect => l10n.orderExpiredReportCta,
    IssueType.merchantRefused => l10n.issueTypeRefused,
  };

  Future<void> _addPhoto() async {
    if (_photos.length >= 3) return;
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (mounted) {
        setState(
          () =>
              _photos.add(PhotoAttachment(bytes: bytes, filename: picked.name)),
        );
      }
    } on Object {
      // No picker support in this environment — the row simply gains no
      // photo; submission still works without one (§5d.6).
    }
  }

  bool get _descriptionValid => _descriptionController.text.trim().length >= 10;

  Future<void> _submit() async {
    final type = _selectedType;
    final order = _order;
    if (type == null || order == null || !_descriptionValid) return;

    setState(() => _phase = _Phase.submitting);
    final repo = ref.read(ordersRepositoryProvider);
    var photosDropped = false;
    final attachmentIds = <String>[];
    for (final photo in _photos) {
      try {
        attachmentIds.add(
          await repo.uploadAttachment(photo.bytes, filename: photo.filename),
        );
      } on Object {
        photosDropped = true;
      }
    }

    try {
      final report = await repo.reportIssue(
        orderId: order.id,
        type: type,
        description: _descriptionController.text.trim(),
        attachmentIds: attachmentIds,
      );
      if (!mounted) return;
      setState(() {
        _report = IssueReport(
          id: report.id,
          referenceNumber: report.referenceNumber,
          type: report.type,
          submittedAt: report.submittedAt,
          slaHours: report.slaHours,
          photosDropped: photosDropped,
        );
        _phase = _Phase.submitted;
      });
      final l10n = AppLocalizations.of(context);
      SemanticsService.announce(
        l10n.issueSubmitted,
        Directionality.of(context),
        assertiveness: Assertiveness.assertive,
      );
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
        title: Text(l10n.issueTitle),
      ),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.loading => const Center(child: CircularProgressIndicator()),
          _Phase.notFound => _Message(
            title: l10n.notFoundTitle,
            body: l10n.notFoundBody,
          ),
          _Phase.error => _ErrorState(onRetry: _load, l10n: l10n),
          _Phase.submitted => _Submitted(report: _report!, l10n: l10n),
          _Phase.idle || _Phase.submitting => _Form(
            order: _order!,
            types: _typesFor(_order!.status),
            typeLabel: (t) => _typeLabel(t, l10n),
            selectedType: _selectedType,
            onTypeSelected: (t) => setState(() => _selectedType = t),
            descriptionController: _descriptionController,
            descriptionValid: _descriptionValid,
            photos: _photos,
            onAddPhoto: _addPhoto,
            onRemovePhoto: (i) => setState(() => _photos.removeAt(i)),
            submitting: _phase == _Phase.submitting,
            onSubmit: _submit,
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
    required this.types,
    required this.typeLabel,
    required this.selectedType,
    required this.onTypeSelected,
    required this.descriptionController,
    required this.descriptionValid,
    required this.photos,
    required this.onAddPhoto,
    required this.onRemovePhoto,
    required this.submitting,
    required this.onSubmit,
    required this.l10n,
  });

  final Order order;
  final List<IssueType> types;
  final String Function(IssueType) typeLabel;
  final IssueType? selectedType;
  final ValueChanged<IssueType> onTypeSelected;
  final TextEditingController descriptionController;
  final bool descriptionValid;
  final List<PhotoAttachment> photos;
  final VoidCallback onAddPhoto;
  final void Function(int) onRemovePhoto;
  final bool submitting;
  final VoidCallback onSubmit;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final showDescriptionError =
        descriptionController.text.isNotEmpty && !descriptionValid;

    return ListView(
      padding: const EdgeInsets.all(Space.x4),
      children: [
        if (selectedType == IssueType.foodSafety) ...[
          AdvisoryBlock(
            title: l10n.foodSafetyAdvisoryTitle,
            body: l10n.foodSafetyAdvisoryBody,
          ),
          const SizedBox(height: Space.x4),
        ],
        Text(
          l10n.issueTypeSectionLabel,
          style: context.type.title,
        ),
        const SizedBox(height: Space.x2),
        for (final type in types) ...[
          SelectableCard(
            label: typeLabel(type),
            selected: selectedType == type,
            onSelected: () => onTypeSelected(type),
          ),
          const SizedBox(height: Space.listGap),
        ],
        const SizedBox(height: Space.x4),
        Text(l10n.issueDescriptionLabel, style: context.type.title),
        const SizedBox(height: Space.x2),
        TextField(
          controller: descriptionController,
          maxLines: 4,
          decoration: InputDecoration(
            errorText: showDescriptionError
                ? l10n.issueDescriptionTooShort
                : null,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: Space.x4),
        PhotoAttachmentRow(
          photos: photos,
          onAdd: onAddPhoto,
          onRemove: onRemovePhoto,
          removeLabelFor: (i) => l10n.issueRemovePhoto(i + 1),
        ),
        const SizedBox(height: Space.x4),
        Text(
          l10n.issueSlaNote(selectedType?.isFoodSafety ?? false ? 2 : 48),
          style: context.type.caption.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: Space.x6),
        AppButton(
          label: l10n.issueSubmitCta,
          isLoading: submitting,
          onPressed: selectedType != null && descriptionValid && !submitting
              ? onSubmit
              : null,
          disabledReason: selectedType == null
              ? l10n.issueTypeSectionLabel
              : l10n.issueDescriptionTooShort,
        ),
      ],
    );
  }
}

class _Submitted extends StatelessWidget {
  const _Submitted({required this.report, required this.l10n});

  final IssueReport report;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isFoodSafety = report.type.isFoodSafety;
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
              isFoodSafety ? l10n.foodSafetyAckTitle : l10n.issueSubmitted,
              style: context.type.display,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.x2),
            Text(
              isFoodSafety
                  ? l10n.foodSafetyAckBody(
                      report.referenceNumber,
                      report.slaHours,
                    )
                  : l10n.issueSlaNote(report.slaHours),
              style: context.type.body.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (report.photosDropped) ...[
              const SizedBox(height: Space.x3),
              Text(
                l10n.issuePhotoUploadFailed,
                style: context.type.caption.copyWith(color: colors.critical.fg),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: Space.x6),
            AppButton(
              label: l10n.back,
              onPressed: () => const OrdersRoute().go(context),
            ),
          ],
        ),
      ),
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
