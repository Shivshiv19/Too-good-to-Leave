import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:surplus_marketplace/app/router/routes.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/core/storage/prefs.dart';
import 'package:surplus_marketplace/core/utils/formatters.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/search_results.dart';
import 'package:surplus_marketplace/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:surplus_marketplace/features/config/domain/entities/taxonomy.dart';
import 'package:surplus_marketplace/features/config/presentation/providers/config_providers.dart';
import 'package:surplus_marketplace/features/location/presentation/providers/location_providers.dart';

enum _Phase { idle, searching, results, noResults, error }

/// §4.2 `/discover/search`, §5b.3.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const _recentSearchesKey = 'catalog.recentSearches';
  static const _maxRecents = 8;
  static const _minQueryLength = 2;

  final _controller = TextEditingController();
  Timer? _debounce;
  _Phase _phase = _Phase.idle;
  List<MerchantResult> _results = const [];
  List<String> _recents = const [];

  @override
  void initState() {
    super.initState();
    _loadRecents();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRecents() async {
    final prefs = await Prefs.open();
    final raw = prefs.getString(_recentSearchesKey);
    if (raw == null) return;
    final list = (jsonDecode(raw) as List<Object?>).cast<String>();
    if (mounted) setState(() => _recents = list);
  }

  Future<void> _saveRecent(String query) async {
    final prefs = await Prefs.open();
    final next = [
      query,
      ..._recents.where((r) => r != query),
    ].take(_maxRecents).toList();
    await prefs.setString(_recentSearchesKey, jsonEncode(next));
    if (mounted) setState(() => _recents = next);
  }

  Future<void> _removeRecent(String query) async {
    final prefs = await Prefs.open();
    final next = _recents.where((r) => r != query).toList();
    await prefs.setString(_recentSearchesKey, jsonEncode(next));
    if (mounted) setState(() => _recents = next);
  }

  void _onChanged() {
    _debounce?.cancel();
    final query = _controller.text.trim();
    if (query.length < _minQueryLength) {
      setState(() => _phase = _Phase.idle);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (!mounted) return;
    setState(() => _phase = _Phase.searching);
    try {
      final cached = await ref
          .read(locationRepositoryProvider)
          .cachedLocation();
      if (cached == null) {
        if (mounted) setState(() => _phase = _Phase.error);
        return;
      }
      final results = await ref
          .read(catalogRepositoryProvider)
          .search(query, cached.latLng);
      if (!mounted) return;
      await _saveRecent(query);
      setState(() {
        _results = results.merchants;
        _phase = results.merchants.isEmpty ? _Phase.noResults : _Phase.results;
      });
    } on Object {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final taxonomy = ref.watch(taxonomyProvider);

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        elevation: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.discoverSearchHint,
            border: InputBorder.none,
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      setState(() => _phase = _Phase.idle);
                    },
                  ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.searchScopeHint,
                style: context.type.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: Space.x4),
              Expanded(child: _buildBody(context, l10n, taxonomy)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<Taxonomy> taxonomyAsync,
  ) {
    final colors = context.colors;
    switch (_phase) {
      case _Phase.idle:
        return ListView(
          children: [
            if (_recents.isNotEmpty) ...[
              Text(
                l10n.searchRecentTitle,
                style: context.type.label.copyWith(color: colors.textSecondary),
              ),
              for (final recent in _recents)
                Semantics(
                  label: recent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history),
                    title: Text(recent),
                    trailing: Semantics(
                      label: l10n.searchRemoveRecentSemantic(recent),
                      button: true,
                      excludeSemantics: true,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => _removeRecent(recent),
                      ),
                    ),
                    onTap: () {
                      _controller.text = recent;
                      _search(recent);
                    },
                  ),
                ),
              const SizedBox(height: Space.x4),
            ],
            Text(
              l10n.searchTrendingTitle,
              style: context.type.label.copyWith(color: colors.textSecondary),
            ),
            taxonomyAsync.when(
              data: (t) => Wrap(
                spacing: Space.x2,
                runSpacing: Space.x2,
                children: [
                  for (final tag in t.categories)
                    ActionChip(
                      label: Text(tag.label),
                      onPressed: () => DiscoverCategoryRoute(
                        categoryId: tag.id,
                      ).push<void>(context),
                    ),
                ],
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        );
      case _Phase.searching:
        return const Center(child: CircularProgressIndicator());
      case _Phase.noResults:
        return Semantics(
          liveRegion: true,
          label: l10n.searchNoResultsTitle(_controller.text),
          child: Padding(
            padding: const EdgeInsets.only(top: Space.x8),
            child: Column(
              children: [
                Text(
                  l10n.searchNoResultsTitle(_controller.text),
                  style: context.type.title,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.x2),
                Text(
                  l10n.searchScopeHint,
                  style: context.type.body.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      case _Phase.error:
        return Center(
          child: Text(
            l10n.errorServerBody,
            style: context.type.body.copyWith(color: colors.textSecondary),
          ),
        );
      case _Phase.results:
        return Semantics(
          liveRegion: true,
          label: l10n.searchResultsAnnouncement(_results.length),
          child: ListView.builder(
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final result = _results[index];
              return ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: Text(result.merchant.displayName),
                subtitle: Text(
                  '${Fmt.distance(result.distanceMetres)} · '
                  '${result.liveBagCount} live',
                ),
                onTap: () => DiscoverMerchantRoute(
                  merchantId: result.merchant.id,
                ).push<void>(context),
              );
            },
          ),
        );
    }
  }
}
