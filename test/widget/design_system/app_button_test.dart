import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';

void main() {
  // Regression test for a bug caught during the first real browser pass
  // (2026-07-27): `secondary` sets both `Material.shape` and
  // `Material.borderRadius`, which `Material` asserts against. Every
  // variant is covered here since none of them were visually verified
  // before that pass.
  for (final variant in AppButtonVariant.values) {
    testWidgets('$variant renders without throwing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: AppButton(label: 'Go', variant: variant, onPressed: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}
