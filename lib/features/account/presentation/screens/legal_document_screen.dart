import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/core/utils/formatters.dart';
import 'package:surplus_marketplace/design_system/components/restricted_markdown_view.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/account/account.dart';

enum _Phase { loading, loaded, notFound, error }

/// §4.2 `/account/legal/:docId`, §5f.9. **Public route** — a prospective
/// user must be able to read the terms before creating an account.
class LegalDocumentScreen extends ConsumerStatefulWidget {
  const LegalDocumentScreen({required this.docId, super.key});

  final String docId;

  @override
  ConsumerState<LegalDocumentScreen> createState() =>
      _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends ConsumerState<LegalDocumentScreen> {
  _Phase _phase = _Phase.loading;
  LegalDocument? _document;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = LegalDocId.fromWire(widget.docId);
    if (id == null) {
      setState(() => _phase = _Phase.notFound);
      return;
    }
    try {
      final document = await ref
          .read(accountRepositoryProvider)
          .getLegalDocument(id);
      if (mounted) {
        setState(() {
          _document = document;
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
    final document = _document;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(backgroundColor: colors.surfaceBase, elevation: 0),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.loading => const Center(child: CircularProgressIndicator()),
          _Phase.notFound => Center(child: Text(l10n.notFoundTitle)),
          _Phase.error => Center(child: Text(l10n.errorServerBody)),
          _Phase.loaded =>
            document == null
                ? const SizedBox.shrink()
                : ListView(
                    padding: const EdgeInsets.all(Space.x4),
                    children: [
                      Text(document.title, style: context.type.display),
                      Text(
                        l10n.legalVersionLine(
                          document.version,
                          Fmt.expectedBy(document.lastUpdated),
                        ),
                        style: context.type.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: Space.x6),
                      RestrictedMarkdownView(source: document.bodyMarkdown),
                    ],
                  ),
        },
      ),
    );
  }
}
