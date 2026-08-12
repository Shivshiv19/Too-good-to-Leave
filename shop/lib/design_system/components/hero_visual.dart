import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';

/// The photo panel shared by every pre-shell screen (registration, pending
/// approval) — a mobile top banner or a desktop side panel, both callers
/// just size it differently via a `SizedBox`/`Expanded`. A bottom scrim
/// guarantees the overlaid title stays legible regardless of what part of
/// the photo lands underneath it.
class HeroVisual extends StatelessWidget {
  const HeroVisual({
    required this.title,
    required this.subtitle,
    this.icon = Icons.storefront_rounded,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/registration_hero.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.centerLeft,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, colors.scrim],
            ),
          ),
        ),
        Positioned(
          left: Space.x5,
          right: Space.x5,
          bottom: Space.x5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 22, color: Colors.white),
              ),
              const SizedBox(height: Space.x3),
              Text(
                title,
                style: context.type.headline.copyWith(color: Colors.white),
              ),
              const SizedBox(height: Space.x1),
              Text(
                subtitle,
                style: context.type.body.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
