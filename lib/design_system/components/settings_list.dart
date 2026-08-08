import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// A titled section of [SettingsRow]s (§5f.1's "grouped menu").
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({required this.title, required this.rows, super.key});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.x4,
              Space.x4,
              Space.x4,
              Space.x1,
            ),
            child: Text(
              title,
              style: context.type.caption.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ...rows,
        ],
      ),
    );
  }
}

/// One row in a [SettingsGroup]. **Auth-gated items announce their gated
/// state** — *"Edit profile, sign in required"* (§5f.1) — rather than
/// appearing available and then bouncing the user to an OTP screen.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.gated = false,
    this.gatedSemanticSuffix,
    this.destructive = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool gated;
  final String? gatedSemanticSuffix;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = destructive ? colors.critical.fg : colors.textPrimary;
    return Semantics(
      button: true,
      label: gated && gatedSemanticSuffix != null
          ? '$label, $gatedSemanticSuffix'
          : label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.x4,
            vertical: Space.x3,
          ),
          child: Row(
            children: [
              Icon(icon, color: gated ? colors.textTertiary : fg),
              const SizedBox(width: Space.x3),
              Expanded(
                child: Text(
                  label,
                  style: context.type.body.copyWith(
                    color: gated ? colors.textTertiary : fg,
                  ),
                ),
              ),
              if (gated)
                Icon(Icons.lock_outline, size: 16, color: colors.textTertiary)
              else
                Icon(Icons.chevron_right, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
