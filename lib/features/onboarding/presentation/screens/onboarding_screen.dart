import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:surplus_marketplace/app/session/session_providers.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/design_system/foundations/motion.dart';
import 'package:surplus_marketplace/features/onboarding/presentation/providers/onboarding_providers.dart';

class _Page {
  const _Page({required this.headline, required this.body, required this.icon});

  final String headline;
  final String body;
  final IconData icon;
}

/// Establishes that the offer is real before any permission or account is
/// asked for (§4.2 `/onboarding`, §5a.2).
///
/// Each of the 3 pages answers one objection — "is this old food?", "is the
/// discount real?", "what do I actually do?" — never framing the customer as
/// a waste-disposal service (§5a.2).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_Page> _pages(AppLocalizations l10n) => [
    _Page(
      headline: l10n.onboardingPage1Headline,
      body: l10n.onboardingPage1Body,
      icon: Icons.schedule,
    ),
    _Page(
      headline: l10n.onboardingPage2Headline,
      body: l10n.onboardingPage2Body,
      icon: Icons.local_offer,
    ),
    _Page(
      headline: l10n.onboardingPage3Headline,
      body: l10n.onboardingPage3Body,
      icon: Icons.storefront,
    ),
  ];

  Future<void> _finish() async {
    await ref.read(onboardingRepositoryProvider).markOnboardingSeen();
    // Flips SessionState immediately, not just on next launch — §4.3 rule 5
    // re-evaluates via `refreshListenable` the moment this fires.
    ref.read(sessionStateProvider).markOnboardingSeen();
    // §3.1 step 3 — location comes right after onboarding, before dietary
    // preference (Phase 8 §8.12 step 4, now built).
    if (mounted) context.go('/location-primer');
  }

  void _goTo(int index) {
    setState(() => _page = index);
    if (!context.prefersReducedMotion) {
      _controller.animateToPage(
        index,
        duration: Motion.standard,
        curve: Motion.easeStandard,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final pages = _pages(l10n);
    final isLast = _page == pages.length - 1;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(Space.x4),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(l10n.onboardingSkip),
                ),
              ),
            ),
            Expanded(
              child: context.prefersReducedMotion
                  ? AnimatedSwitcher(
                      duration: Motion.quick,
                      child: _OnboardingPageContent(
                        key: ValueKey(_page),
                        page: pages[_page],
                      ),
                    )
                  : PageView(
                      controller: _controller,
                      onPageChanged: (index) => setState(() => _page = index),
                      children: [
                        for (final page in pages)
                          _OnboardingPageContent(page: page),
                      ],
                    ),
            ),
            Semantics(
              liveRegion: true,
              label: l10n.onboardingPageIndicatorSemantic(
                _page + 1,
                pages.length,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.x1),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _page
                              ? colors.actionPrimaryBg
                              : colors.borderStrong,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Space.x6),
              child: AppButton(
                label: isLast ? l10n.onboardingGetStarted : l10n.onboardingNext,
                onPressed: isLast ? _finish : () => _goTo(_page + 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageContent extends StatelessWidget {
  const _OnboardingPageContent({required this.page, super.key});

  final _Page page;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.all(Space.x8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Decorative — the real content is the headline/body below.
          ExcludeSemantics(
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.actionPrimaryBg.withValues(alpha: 0.12),
              ),
              alignment: Alignment.center,
              child: Icon(page.icon, size: 96, color: colors.actionPrimaryBg),
            ),
          ),
          const SizedBox(height: Space.x8),
          Text(
            page.headline,
            style: context.type.display,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Space.x3),
          Text(
            page.body,
            style: context.type.body.copyWith(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
