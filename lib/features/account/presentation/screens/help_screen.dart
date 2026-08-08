import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:surplus_marketplace/app/router/routes.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/account/account.dart';

enum _Phase { loading, loaded, error }

/// §4.2 `/account/help`, §5f.6.
class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  _Phase _phase = _Phase.loading;
  List<HelpTopic> _topics = const [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final topics = await ref.read(accountRepositoryProvider).getHelpTopics();
      if (mounted) {
        setState(() {
          _topics = topics;
          _phase = _Phase.loaded;
        });
      }
    } on Object {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  String _categoryLabel(HelpCategory category, AppLocalizations l10n) =>
      switch (category) {
        HelpCategory.reservations => l10n.helpCategoryReservations,
        HelpCategory.pickup => l10n.helpCategoryPickup,
        HelpCategory.paymentsRefunds => l10n.helpCategoryPaymentsRefunds,
        HelpCategory.account => l10n.helpCategoryAccount,
        HelpCategory.foodSafety => l10n.helpCategoryFoodSafety,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final filtered = _query.trim().isEmpty
        ? _topics
        : _topics
              .where(
                (t) => t.title.toLowerCase().contains(_query.toLowerCase()),
              )
              .toList();
    final grouped = <HelpCategory, List<HelpTopic>>{};
    for (final topic in filtered) {
      grouped.putIfAbsent(topic.category, () => []).add(topic);
    }

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        elevation: 0,
        title: Text(l10n.accountHelp),
      ),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.loading => const Center(child: CircularProgressIndicator()),
          _Phase.error => Center(
            child: Padding(
              padding: const EdgeInsets.all(Space.x6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.helpNoCacheBody, textAlign: TextAlign.center),
                  const SizedBox(height: Space.x4),
                  AppButton(
                    label: l10n.accountContact,
                    onPressed: () => const AccountContactRoute().go(context),
                  ),
                ],
              ),
            ),
          ),
          _Phase.loaded => ListView(
            padding: const EdgeInsets.all(Space.x4),
            children: [
              TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: l10n.helpSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: Space.x4),
              for (final entry in grouped.entries) ...[
                Text(
                  _categoryLabel(entry.key, l10n),
                  style: context.type.title,
                ),
                const SizedBox(height: Space.x2),
                for (final topic in entry.value)
                  ListTile(
                    title: Text(topic.title),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => AccountHelpTopicRoute(
                      topicId: topic.id,
                    ).push<void>(context),
                  ),
                const SizedBox(height: Space.x4),
              ],
              const Divider(),
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: Text(l10n.accountContact),
                onTap: () => const AccountContactRoute().go(context),
              ),
            ],
          ),
        },
      ),
    );
  }
}
