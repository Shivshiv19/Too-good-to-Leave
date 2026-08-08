import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:surplus_marketplace/app/router/routes.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/components/restricted_markdown_view.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/account/account.dart';

enum _Phase { loading, loaded, notFound, error }

/// §4.2 `/account/help/:topicId`, §5f.7.
class FaqTopicScreen extends ConsumerStatefulWidget {
  const FaqTopicScreen({required this.topicId, super.key});

  final String topicId;

  @override
  ConsumerState<FaqTopicScreen> createState() => _FaqTopicScreenState();
}

class _FaqTopicScreenState extends ConsumerState<FaqTopicScreen> {
  _Phase _phase = _Phase.loading;
  HelpTopic? _topic;
  bool? _wasHelpful;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final topic = await ref
          .read(accountRepositoryProvider)
          .getHelpTopic(widget.topicId);
      if (mounted) {
        setState(() {
          _topic = topic;
          _phase = _Phase.loaded;
        });
      }
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
    final topic = _topic;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(backgroundColor: colors.surfaceBase, elevation: 0),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.loading => const Center(child: CircularProgressIndicator()),
          _Phase.notFound => Center(child: Text(l10n.notFoundTitle)),
          _Phase.error => Center(child: Text(l10n.errorServerBody)),
          _Phase.loaded =>
            topic == null
                ? const SizedBox.shrink()
                : ListView(
                    padding: const EdgeInsets.all(Space.x4),
                    children: [
                      Text(topic.title, style: context.type.display),
                      const SizedBox(height: Space.x4),
                      RestrictedMarkdownView(source: topic.body),
                      const SizedBox(height: Space.x6),
                      Text(l10n.faqWasHelpful, style: context.type.title),
                      const SizedBox(height: Space.x2),
                      Row(
                        children: [
                          AppButton(
                            label: l10n.faqHelpfulYes,
                            variant: _wasHelpful == true
                                ? AppButtonVariant.primary
                                : AppButtonVariant.secondary,
                            size: AppButtonSize.small,
                            expand: false,
                            onPressed: () => setState(() => _wasHelpful = true),
                          ),
                          const SizedBox(width: Space.x2),
                          AppButton(
                            label: l10n.faqHelpfulNo,
                            variant: _wasHelpful == false
                                ? AppButtonVariant.primary
                                : AppButtonVariant.secondary,
                            size: AppButtonSize.small,
                            expand: false,
                            onPressed: () =>
                                setState(() => _wasHelpful = false),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.x6),
                      AppButton(
                        label: l10n.accountContact,
                        variant: AppButtonVariant.tertiary,
                        onPressed: () =>
                            const AccountContactRoute().go(context),
                      ),
                    ],
                  ),
        },
      ),
    );
  }
}
