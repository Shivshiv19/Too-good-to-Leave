import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';

/// A customer's avatar, with an **initials fallback** (§5f.1) — never a
/// broken-image icon for the common case of "no photo set".
///
/// Accepts either a `data:` URI (this fake's own "uploaded" avatars have
/// nowhere real to live) or an `https:` URL, transparently.
class AvatarImage extends StatelessWidget {
  const AvatarImage({
    required this.avatarUrl,
    required this.name,
    this.size = 48,
    super.key,
  });

  final String? avatarUrl;
  final String? name;
  final double size;

  String get _initials {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    final first = parts.first.characters.first;
    final last = parts.length > 1 ? parts.last.characters.first : '';
    return '$first$last'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final url = avatarUrl;

    Widget fallback() => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: context.type.title.copyWith(color: colors.textSecondary),
      ),
    );

    if (url == null || url.isEmpty) return fallback();

    if (url.startsWith('data:')) {
      final bytes = _decodeDataUri(url);
      if (bytes == null) return fallback();
      return ClipOval(
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) => fallback(),
        placeholder: (context, url) => fallback(),
      ),
    );
  }

  Uint8List? _decodeDataUri(String uri) {
    try {
      final commaIndex = uri.indexOf(',');
      return base64Decode(uri.substring(commaIndex + 1));
    } on Object {
      return null;
    }
  }
}
