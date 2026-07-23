import 'dart:async';

import 'package:flutter/material.dart';

import '../../../theme/app_motion.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/app_bullet_item.dart';
import '../../../widgets/bulls_cows_example.dart';
import '../models/onboarding_page_model.dart';

/// The 4 onboarding pages, in display order. Plain data — see
/// [OnboardingPageModel]'s own doc — so [OnboardingScreen] itself owns no
/// copy beyond this list.
const List<OnboardingPageModel> _onboardingPages = [
  OnboardingPageModel(
    icon: Icons.flag_outlined,
    title: 'Guess the Secret Word',
    bullets: [
      'Guess the hidden 4-letter word.',
      'You have 10 attempts.',
      'Every submitted guess must be a valid word.',
    ],
  ),
  OnboardingPageModel(
    icon: Icons.gps_fixed,
    title: 'Bulls and Cows',
    bullets: [
      'A Bull is a correct letter in the correct position.',
      'A Cow is a correct letter in the wrong position.',
    ],
    example: true,
  ),
  OnboardingPageModel(
    icon: Icons.lightbulb_outline,
    title: 'Difficulty and Hints',
    bullets: [
      'Easy, Medium, and Hard use different word familiarity levels.',
      'A hint reveals one correct letter and its exact position.',
      'Easy and Medium allow one paid hint.',
      "Hard gives one free hint, then one paid hint.",
      'A paid hint costs 20 coins.',
    ],
  ),
  OnboardingPageModel(
    icon: Icons.emoji_events_outlined,
    title: 'Track Your Progress',
    bullets: [
      'Win games to earn coins.',
      'Complete at least one game each day to keep your streak going.',
      'Play the same offline Daily Challenge as other players on this '
          'app version.',
      'Results and progress are stored only on this device.',
    ],
  ),
];

/// The first-launch onboarding flow, also reachable later as "View
/// Tutorial" from Settings or Rules.
///
/// Purely presentational: it owns only which page is currently showing as
/// local UI state, and reports completion through [onDone] — called
/// identically whether the player taps Skip or Finish, since both mean the
/// same thing here: "stop showing this and go back to what I was doing".
/// The app-level composition root decides what [onDone] actually does:
/// during first launch it marks onboarding complete via
/// `OnboardingController.markCompleted` (no navigation, since this screen is
/// shown in place of Home, not pushed); when reopened manually from Settings
/// or Rules it simply pops the pushed route without touching the controller
/// again (see `app.dart`) — reopening the tutorial must never alter or reset
/// any other app data.
///
/// Never reads or writes [SharedPreferences]/any [PreferencesStore] itself —
/// persistence stays entirely behind [onDone]'s caller, per this project's
/// "UI must not access storage directly" rule (see CLAUDE.md).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  /// Called when the player finishes or skips onboarding. See the
  /// class-level doc for what each caller actually does with it.
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _page = 0;

  bool get _isLastPage => _page == _onboardingPages.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    unawaited(
      _pageController.animateToPage(
        page,
        duration: AppMotion.durationFor(context, AppMotion.standard),
        curve: AppMotion.curve,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome'),
        actions: [
          if (!_isLastPage)
            Semantics(
              button: true,
              label: 'Skip tutorial',
              child: ExcludeSemantics(
                child: TextButton(
                  onPressed: widget.onDone,
                  child: const Text('Skip'),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _page = page),
                children: [
                  for (final page in _onboardingPages)
                    _OnboardingPageView(page: page),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              label: 'Page ${_page + 1} of ${_onboardingPages.length}',
              child: ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _onboardingPages.length; i++)
                      AnimatedContainer(
                        duration: AppMotion.durationFor(
                          context,
                          AppMotion.fast,
                        ),
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs / 2,
                        ),
                        width: i == _page ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Visibility(
                      visible: _page > 0,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      child: OutlinedButton(
                        onPressed: _page > 0
                            ? () => _goToPage(_page - 1)
                            : null,
                        child: const Text('Back'),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isLastPage
                          ? widget.onDone
                          : () => _goToPage(_page + 1),
                      child: Text(_isLastPage ? 'Finish' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageView extends StatelessWidget {
  const _OnboardingPageView({required this.page});

  final OnboardingPageModel page;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(page.icon, size: 56, color: colorScheme.primary),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            header: true,
            child: Text(
              page.title,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final bullet in page.bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppBulletItem(text: bullet, style: textTheme.bodyLarge),
            ),
          if (page.example) ...[
            const SizedBox(height: AppSpacing.md),
            const BullsCowsExample(),
          ],
        ],
      ),
    );
  }
}
