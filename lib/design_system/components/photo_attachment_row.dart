import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// One selected photo, pending upload as part of an issue report (§5d.6).
class PhotoAttachment {
  const PhotoAttachment({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

/// A row of photo thumbnails with **per-item remove actions** (§5d.6's
/// hand-off to Phase 6), plus an "add" tile up to [maxPhotos].
///
/// Thumbnails are labelled individually — *"Photo 1 of 3"* plus a distinct
/// *"Remove photo 1"* action — never a bare image with no accessible name
/// (§5d.6's own accessibility requirement).
class PhotoAttachmentRow extends StatelessWidget {
  const PhotoAttachmentRow({
    required this.photos,
    required this.onAdd,
    required this.onRemove,
    required this.removeLabelFor,
    this.maxPhotos = 3,
    super.key,
  });

  final List<PhotoAttachment> photos;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  /// Resolved by the caller so this stays free of l10n — e.g.
  /// `(i) => l10n.issueRemovePhoto(i + 1)`.
  final String Function(int index) removeLabelFor;

  final int maxPhotos;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length + (photos.length < maxPhotos ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(width: Space.x2),
        itemBuilder: (context, index) {
          if (index == photos.length) {
            return Semantics(
              button: true,
              label: 'Add photo',
              excludeSemantics: true,
              child: InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(Radii.md),
                child: Container(
                  width: 88,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: Icon(
                    Icons.add_photo_alternate_outlined,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            );
          }
          return Semantics(
            label: 'Photo ${index + 1} of ${photos.length}',
            container: true,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.md),
                  child: Image.memory(
                    photos[index].bytes,
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: Semantics(
                    button: true,
                    label: removeLabelFor(index),
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: () => onRemove(index),
                      borderRadius: BorderRadius.circular(Radii.full),
                      child: Container(
                        padding: const EdgeInsets.all(Space.x1),
                        decoration: BoxDecoration(
                          color: colors.scrim,
                          borderRadius: BorderRadius.circular(Radii.full),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
