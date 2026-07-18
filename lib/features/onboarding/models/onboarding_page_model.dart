import 'package:flutter/widgets.dart';

/// One page of the first-launch onboarding flow (see `OnboardingScreen`).
///
/// Purely data: an icon, a short title, and a handful of one-line bullet
/// points. Carries no Flutter widget beyond [icon] itself, so the list of
/// pages can be built once as plain, testable data — [OnboardingScreen]
/// alone decides layout. [example], when `true`, tells [OnboardingScreen] to
/// additionally render the shared `BullsCowsExample` widget beneath this
/// page's bullets — used only by the Bulls and Cows page, which benefits
/// from a worked example alongside its plain-text explanation.
@immutable
class OnboardingPageModel {
  const OnboardingPageModel({
    required this.icon,
    required this.title,
    required this.bullets,
    this.example = false,
  });

  /// A decorative icon representing this page's topic.
  final IconData icon;

  /// The page's short, human-facing heading.
  final String title;

  /// Short, one-line explanations shown as a bulleted list.
  final List<String> bullets;

  /// Whether this page also shows the shared Bulls/Cows visual example.
  final bool example;
}
