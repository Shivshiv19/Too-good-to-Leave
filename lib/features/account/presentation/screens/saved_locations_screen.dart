import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/account/account.dart';
import 'package:surplus_marketplace/features/location/location.dart';

enum _Phase { loading, loaded, error }

/// §4.2 `/account/locations`, §5f.3 — **discovery anchors, not delivery
/// addresses** (§2.7.1).
class SavedLocationsScreen extends ConsumerStatefulWidget {
  const SavedLocationsScreen({super.key});

  @override
  ConsumerState<SavedLocationsScreen> createState() =>
      _SavedLocationsScreenState();
}

class _SavedLocationsScreenState extends ConsumerState<SavedLocationsScreen> {
  _Phase _phase = _Phase.loading;
  List<SavedLocation> _locations = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final locations = await ref
          .read(accountRepositoryProvider)
          .getSavedLocations();
      if (mounted) {
        setState(() {
          _locations = locations;
          _phase = _Phase.loaded;
        });
      }
    } on Object {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  Future<void> _addNew() async {
    final l10n = AppLocalizations.of(context);
    final query = await showSearch<LocalitySuggestion?>(
      context: context,
      delegate: _LocalitySearchDelegate(
        repo: ref.read(locationRepositoryProvider),
        hint: l10n.savedLocationsSearchHint,
      ),
    );
    if (query == null || !mounted) return;
    final label = await _promptLabel(context, initial: '');
    if (label == null || label.trim().isEmpty) return;
    try {
      await ref
          .read(accountRepositoryProvider)
          .addSavedLocation(
            label: label.trim(),
            location: ResolvedLocation(
              latLng: query.latLng,
              locality: query.locality,
              city: query.city,
              pincode: query.pincode,
              precision: LocationPrecision.precise,
              source: LocationSource.search,
            ),
          );
      await _load();
    } on ValidationException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.savedLocationsCapReached)));
      }
    }
  }

  Future<String?> _promptLabel(
    BuildContext context, {
    required String initial,
  }) {
    final controller = TextEditingController(text: initial);
    final l10n = AppLocalizations.of(context);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.savedLocationsLabelPrompt),
        content: TextField(
          controller: controller,
          maxLength: 30,
          decoration: InputDecoration(hintText: l10n.savedLocationsLabelHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l10n.savedLocationsSave),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(SavedLocation location) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.savedLocationsDeleteTitle(location.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.savedLocationsDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final previous = _locations;
    setState(
      () => _locations = _locations.where((l) => l.id != location.id).toList(),
    );
    try {
      await ref
          .read(accountRepositoryProvider)
          .deleteSavedLocation(location.id);
    } on Object {
      if (mounted) setState(() => _locations = previous);
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
        title: Text(l10n.accountSavedLocations),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _addNew),
        ],
      ),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.loading => const Center(child: CircularProgressIndicator()),
          _Phase.error => Center(child: Text(l10n.errorServerBody)),
          _Phase.loaded =>
            _locations.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Space.x6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.savedLocationsEmptyTitle,
                            style: context.type.title,
                          ),
                          const SizedBox(height: Space.x4),
                          AppButton(
                            label: l10n.savedLocationsAdd,
                            onPressed: _addNew,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(Space.x4),
                    itemCount: _locations.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: Space.listGap),
                    itemBuilder: (context, i) {
                      final location = _locations[i];
                      return Semantics(
                        label: location.isDefault
                            ? l10n.savedLocationsDefaultSemantic(location.label)
                            : location.label,
                        excludeSemantics: true,
                        child: Container(
                          padding: const EdgeInsets.all(Space.x3),
                          decoration: BoxDecoration(
                            color: colors.surfaceRaised,
                            borderRadius: BorderRadius.circular(Radii.card),
                            border: Border.all(color: colors.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          location.label,
                                          style: context.type.title,
                                        ),
                                        if (location.isDefault) ...[
                                          const SizedBox(width: Space.x2),
                                          Text(
                                            l10n.savedLocationsDefaultBadge,
                                            style: context.type.caption
                                                .copyWith(
                                                  color: colors.success.fg,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      location.location.displayLabel,
                                      style: context.type.caption.copyWith(
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'default') {
                                    await ref
                                        .read(accountRepositoryProvider)
                                        .setDefaultSavedLocation(location.id);
                                    await _load();
                                  } else if (value == 'delete') {
                                    await _delete(location);
                                  }
                                },
                                itemBuilder: (context) => [
                                  if (!location.isDefault)
                                    PopupMenuItem(
                                      value: 'default',
                                      child: Text(
                                        l10n.savedLocationsSetDefault,
                                      ),
                                    ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(l10n.savedLocationsDelete),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        },
      ),
    );
  }
}

class _LocalitySearchDelegate extends SearchDelegate<LocalitySuggestion?> {
  _LocalitySearchDelegate({required this.repo, required String hint})
    : super(searchFieldLabel: hint);

  final LocationRepository repo;

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _suggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) => _suggestions(context);

  Widget _suggestions(BuildContext context) {
    if (query.trim().isEmpty) return const SizedBox.shrink();
    return FutureBuilder<List<LocalitySuggestion>>(
      future: repo.search(query),
      builder: (context, snapshot) {
        final results = snapshot.data ?? const [];
        return ListView(
          children: [
            for (final r in results)
              ListTile(title: Text(r.label), onTap: () => close(context, r)),
          ],
        );
      },
    );
  }
}
