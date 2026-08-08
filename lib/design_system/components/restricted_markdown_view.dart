import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// Renders **a restricted markdown subset only** — `#`/`##` headings,
/// `- ` bullet lines, `**bold**` spans, and blank-line-separated
/// paragraphs. **Never arbitrary HTML** (§5f.7/§5f.9's own security rule):
/// rendering unconstrained remote markup in an authenticated app context
/// is an injection vector, so this is a hand-rolled parser for exactly the
/// subset above rather than a general-purpose markdown package that might
/// pass through more than that.
///
/// Heading structure is preserved as real `Semantics(header: true)` nodes
/// so heading navigation works — for a long legal document, that's the
/// primary screen-reader affordance (§5f.9's own accessibility rule).
class RestrictedMarkdownView extends StatelessWidget {
  const RestrictedMarkdownView({required this.source, super.key});

  final String source;

  @override
  Widget build(BuildContext context) {
    final blocks = _parse(source);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final block in blocks) _renderBlock(context, block)],
    );
  }

  List<_Block> _parse(String source) {
    final blocks = <_Block>[];
    final lines = source.split('\n');
    var i = 0;
    while (i < lines.length) {
      final line = lines[i].trimRight();
      if (line.isEmpty) {
        i++;
        continue;
      }
      if (line.startsWith('## ')) {
        blocks.add(_Block(_BlockType.heading2, line.substring(3)));
      } else if (line.startsWith('# ')) {
        blocks.add(_Block(_BlockType.heading1, line.substring(2)));
      } else if (line.startsWith('- ')) {
        final items = <String>[];
        while (i < lines.length && lines[i].trimRight().startsWith('- ')) {
          items.add(lines[i].trimRight().substring(2));
          i++;
        }
        blocks.add(_Block(_BlockType.list, items.join('\n')));
        continue;
      } else {
        blocks.add(_Block(_BlockType.paragraph, line));
      }
      i++;
    }
    return blocks;
  }

  Widget _renderBlock(BuildContext context, _Block block) {
    final colors = context.colors;
    switch (block.type) {
      case _BlockType.heading1:
        return Padding(
          padding: const EdgeInsets.only(top: Space.x6, bottom: Space.x2),
          child: Semantics(
            header: true,
            child: Text(block.text, style: context.type.display),
          ),
        );
      case _BlockType.heading2:
        return Padding(
          padding: const EdgeInsets.only(top: Space.x5, bottom: Space.x2),
          child: Semantics(
            header: true,
            child: Text(block.text, style: context.type.title),
          ),
        );
      case _BlockType.list:
        return Padding(
          padding: const EdgeInsets.only(bottom: Space.x3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in block.text.split('\n'))
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.x1),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•  ', style: context.type.body),
                      Expanded(
                        child: _RichLine(item, style: context.type.body),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      case _BlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: Space.x3),
          child: _RichLine(
            block.text,
            style: context.type.body.copyWith(color: colors.textPrimary),
          ),
        );
    }
  }
}

enum _BlockType { heading1, heading2, list, paragraph }

class _Block {
  const _Block(this.type, this.text);

  final _BlockType type;
  final String text;
}

/// Renders `**bold**` spans within an otherwise plain line.
class _RichLine extends StatelessWidget {
  const _RichLine(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    var last = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      last = match.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(style: style, children: spans));
  }
}
