import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';

/// §5e.2's undoable unsave — cheap, and it prevents the irritating loss of
/// a list built up over weeks. A thin wrapper over [ScaffoldMessenger] so
/// every undo-capable action in the app shows the same shape.
void showUndoSnackbar(
  BuildContext context, {
  required String message,
  required String undoLabel,
  required VoidCallback onUndo,
}) {
  final colors = context.colors;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: undoLabel,
          textColor: colors.actionPrimaryBg,
          onPressed: onUndo,
        ),
      ),
    );
}
