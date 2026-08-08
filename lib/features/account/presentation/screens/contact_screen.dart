import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/account/account.dart';
import 'package:surplus_marketplace/features/config/config.dart';

enum _Phase { idle, submitting, submitted, error }

/// §4.2 `/account/contact`, §5f.8.
class ContactScreen extends ConsumerStatefulWidget {
  const ContactScreen({super.key});

  @override
  ConsumerState<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends ConsumerState<ContactScreen> {
  _Phase _phase = _Phase.idle;
  ContactCategory? _category;
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _category != null && _messageController.text.trim().length >= 20;

  Future<void> _submit() async {
    setState(() => _phase = _Phase.submitting);
    try {
      await ref
          .read(accountRepositoryProvider)
          .submitContactRequest(
            category: _category!,
            message: _messageController.text.trim(),
          );
      if (mounted) setState(() => _phase = _Phase.submitted);
    } on Object {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  String _categoryLabel(ContactCategory category, AppLocalizations l10n) =>
      switch (category) {
        ContactCategory.reservation => l10n.helpCategoryReservations,
        ContactCategory.pickup => l10n.helpCategoryPickup,
        ContactCategory.paymentsRefunds => l10n.helpCategoryPaymentsRefunds,
        ContactCategory.account => l10n.helpCategoryAccount,
        ContactCategory.other => l10n.contactCategoryOther,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final policyValues = ref.watch(remoteConfigProvider).value?.policyValues;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        elevation: 0,
        title: Text(l10n.accountContact),
      ),
      body: SafeArea(
        child: _phase == _Phase.submitted
            ? Center(
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
                      Text(l10n.contactSubmitted, style: context.type.title),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(Space.x4),
                children: [
                  Text(l10n.contactChannels, style: context.type.title),
                  const SizedBox(height: Space.x2),
                  Text(
                    l10n.contactWhatsappBody,
                    style: context.type.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: Space.x2),
                  Text(
                    l10n.contactSlaBody,
                    style: context.type.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  if (policyValues != null) ...[
                    const SizedBox(height: Space.x4),
                    Text(
                      l10n.contactGrievanceOfficer,
                      style: context.type.title,
                    ),
                    Text(
                      policyValues.grievanceOfficer.name,
                      style: context.type.body,
                    ),
                    Text(
                      policyValues.grievanceOfficer.designation,
                      style: context.type.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    Text(
                      policyValues.grievanceOfficer.email,
                      style: context.type.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    Text(
                      policyValues.grievanceOfficer.phone,
                      style: context.type.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                  const Divider(height: Space.x8),
                  Text(l10n.contactFormTitle, style: context.type.title),
                  const SizedBox(height: Space.x3),
                  Wrap(
                    spacing: Space.x2,
                    children: [
                      for (final category in ContactCategory.values)
                        ChoiceChip(
                          label: Text(_categoryLabel(category, l10n)),
                          selected: _category == category,
                          onSelected: (_) =>
                              setState(() => _category = category),
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.x4),
                  TextField(
                    controller: _messageController,
                    maxLines: 5,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: l10n.contactMessageLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (_phase == _Phase.error) ...[
                    const SizedBox(height: Space.x3),
                    Text(
                      l10n.errorServerBody,
                      style: TextStyle(color: colors.critical.fg),
                    ),
                  ],
                  const SizedBox(height: Space.x6),
                  AppButton(
                    label: l10n.contactSubmitCta,
                    isLoading: _phase == _Phase.submitting,
                    onPressed: _canSubmit && _phase != _Phase.submitting
                        ? _submit
                        : null,
                  ),
                ],
              ),
      ),
    );
  }
}
