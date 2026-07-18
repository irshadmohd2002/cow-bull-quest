import 'package:flutter/material.dart';

import '../../../app_settings.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/confirm_dialog.dart';

/// Lets the player choose the app's theme preference and open the privacy
/// policy.
///
/// Purely presentational: it does not own [AppThemePreference] state itself
/// and imports no `home` or `game` feature file. It receives the
/// currently-selected [themePreference] and reports every selection through
/// [onThemePreferenceChanged]; the app-level composition root owns the
/// actual [AppSettings] instance and decides what happens with the change.
///
/// Likewise, this screen never knows the privacy-policy URL, whether it is
/// release-ready, or how an external link is opened — it only renders the
/// "Privacy Policy" row as enabled or disabled based on whether
/// [onOpenPrivacyPolicy] is non-null, and reports a tap through that neutral
/// callback. The composition root ([onOpenPrivacyPolicy]'s caller) decides
/// the URL, whether it's ready to show, and how to launch it.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.themePreference,
    required this.onThemePreferenceChanged,
    required this.onOpenPrivacyPolicy,
    required this.soundEffectsEnabled,
    required this.onSoundEffectsChanged,
    required this.musicEnabled,
    required this.onMusicChanged,
    required this.hapticsEnabled,
    required this.onHapticsChanged,
    required this.onViewTutorial,
    this.onResetLocalData,
  });

  /// The currently-selected theme preference.
  final AppThemePreference themePreference;

  /// Called with the newly-selected preference whenever the player picks a
  /// different option.
  final ValueChanged<AppThemePreference> onThemePreferenceChanged;

  /// Whether interface/gameplay sound effects are currently enabled.
  final bool soundEffectsEnabled;

  /// Called with the new value whenever the player toggles sound effects.
  final ValueChanged<bool> onSoundEffectsChanged;

  /// Whether the background-music loop is currently enabled.
  final bool musicEnabled;

  /// Called with the new value whenever the player toggles background
  /// music.
  final ValueChanged<bool> onMusicChanged;

  /// Whether haptic feedback is currently enabled.
  final bool hapticsEnabled;

  /// Called with the new value whenever the player toggles haptic feedback.
  final ValueChanged<bool> onHapticsChanged;

  /// Called when the player taps "Privacy Policy", or `null` to render that
  /// row disabled.
  ///
  /// `null` is used — rather than, say, a boolean "enabled" flag alongside
  /// an always-present callback — so there is exactly one source of truth
  /// for whether the row is interactive: a disabled row can never
  /// accidentally invoke a callback because there is no callback to invoke.
  /// The composition root passes `null` while the configured privacy-policy
  /// URL isn't release-ready yet (see `core/privacy_policy.dart`).
  final VoidCallback? onOpenPrivacyPolicy;

  /// Called when the player taps "View Tutorial" to manually replay
  /// first-launch onboarding. Reopening it this way never resets or alters
  /// any other app data — see `OnboardingScreen`'s own doc.
  final VoidCallback onViewTutorial;

  /// Called after the player confirms Settings' own "Reset local data"
  /// dialog, or `null` to hide that row entirely — the same "`null` gates
  /// visibility" pattern [onOpenPrivacyPolicy] uses. This screen shows its
  /// own confirmation dialog itself (naming every category of data it
  /// clears) before ever invoking this.
  final VoidCallback? onResetLocalData;

  static const Map<AppThemePreference, String> _labels = {
    AppThemePreference.system: 'Follow system',
    AppThemePreference.light: 'Light',
    AppThemePreference.dark: 'Dark',
  };

  static const Map<AppThemePreference, String> _descriptions = {
    AppThemePreference.system: "Match your device's current appearance.",
    AppThemePreference.light: 'Always use the light appearance.',
    AppThemePreference.dark: 'Always use the dark appearance.',
  };

  static const Map<AppThemePreference, IconData> _icons = {
    AppThemePreference.system: Icons.brightness_auto,
    AppThemePreference.light: Icons.light_mode,
    AppThemePreference.dark: Icons.dark_mode,
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: RadioGroup<AppThemePreference>(
            groupValue: themePreference,
            onChanged: (selected) {
              if (selected != null) onThemePreferenceChanged(selected);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text('Theme', style: textTheme.titleMedium),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Choose how Cow Bull Quest looks on this device.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final preference in AppThemePreference.values)
                        RadioListTile<AppThemePreference>(
                          secondary: Icon(
                            _icons[preference],
                            color: preference == themePreference
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            _labels[preference]!,
                            style: TextStyle(
                              fontWeight: preference == themePreference
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          // Excluded from semantics so the announced label
                          // stays the concise option name — the fuller
                          // description is a sighted-only visual aid, not
                          // additional information a screen-reader user
                          // needs repeated on every option.
                          subtitle: ExcludeSemantics(
                            child: Text(_descriptions[preference]!),
                          ),
                          value: preference,
                          selected: preference == themePreference,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  header: true,
                  child: Text('Audio & Feedback', style: textTheme.titleMedium),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Control sound, music, and vibration feedback.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: Icon(
                          soundEffectsEnabled
                              ? Icons.volume_up
                              : Icons.volume_off,
                          color: soundEffectsEnabled
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                        title: const Text('Sound effects'),
                        subtitle: const Text(
                          'Plays interface and gameplay sound effects.',
                        ),
                        value: soundEffectsEnabled,
                        onChanged: onSoundEffectsChanged,
                      ),
                      SwitchListTile(
                        secondary: Icon(
                          Icons.music_note,
                          color: musicEnabled
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                        title: const Text('Background music'),
                        subtitle: const Text(
                          'Plays subtle music while using the app.',
                        ),
                        value: musicEnabled,
                        onChanged: onMusicChanged,
                      ),
                      SwitchListTile(
                        secondary: Icon(
                          Icons.vibration,
                          color: hapticsEnabled
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                        title: const Text('Haptic feedback'),
                        subtitle: const Text(
                          'Uses light vibration feedback for important '
                          'actions.',
                        ),
                        value: hapticsEnabled,
                        onChanged: onHapticsChanged,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  header: true,
                  child: Text('Help', style: textTheme.titleMedium),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Replay the introduction to how Cow Bull Quest works.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Semantics(
                    button: true,
                    label:
                        'View Tutorial. Replay the first-launch '
                        'introduction. This does not change your coins, '
                        'statistics, streaks, or other settings.',
                    child: ExcludeSemantics(
                      child: ListTile(
                        leading: const Icon(Icons.school_outlined),
                        title: const Text('View Tutorial'),
                        subtitle: const Text(
                          'Replaying it never changes your progress or '
                          'settings.',
                        ),
                        onTap: onViewTutorial,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  header: true,
                  child: Text('About', style: textTheme.titleMedium),
                ),
                const SizedBox(height: AppSpacing.md),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: _PrivacyPolicyListTile(
                    onOpenPrivacyPolicy: onOpenPrivacyPolicy,
                  ),
                ),
                if (onResetLocalData != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Semantics(
                    header: true,
                    child: Text('Data', style: textTheme.titleMedium),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Permanently erase everything saved on this device.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Semantics(
                      button: true,
                      label:
                          'Reset local data. Permanently clears your coins, '
                          'statistics, streaks, and Daily Challenge history '
                          'on this device.',
                      child: ExcludeSemantics(
                        child: ListTile(
                          leading: Icon(
                            Icons.delete_forever_outlined,
                            color: colorScheme.error,
                          ),
                          title: Text(
                            'Reset local data',
                            style: TextStyle(color: colorScheme.error),
                          ),
                          subtitle: const Text(
                            'Clears coins, statistics, streaks, and Daily '
                            'Challenge history on this device.',
                          ),
                          onTap: () => _confirmResetLocalData(
                            context,
                            onResetLocalData!,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows Settings' "Reset local data" confirmation — explicitly naming every
/// category of data it clears, including onboarding/tutorial completion —
/// and, only if confirmed, calls [onConfirmed]. Mirrors the same
/// show-dialog-then-call-back shape `StatisticsScreen`'s own
/// `_confirmClear` uses for its destructive action.
Future<void> _confirmResetLocalData(
  BuildContext context,
  VoidCallback onConfirmed,
) async {
  final confirmed = await showConfirmDialog(
    context,
    title: 'Reset local data?',
    body:
        'This permanently clears your coins, statistics, streaks, Daily '
        'Challenge history, tutorial completion, and app preferences '
        '(theme, sound, music, and haptics) on this device. This cannot be '
        'undone.',
    confirmLabel: 'Reset',
  );
  if (confirmed) onConfirmed();
}

/// The "Privacy Policy" row: enabled and reporting taps through
/// [onOpenPrivacyPolicy] when non-null, otherwise disabled with supporting
/// text explaining why. Never color-only — the disabled state also changes
/// the supporting text and removes tap interactivity, both independent of
/// color, and [ListTile.enabled] surfaces the disabled state to assistive
/// technology on its own.
class _PrivacyPolicyListTile extends StatelessWidget {
  const _PrivacyPolicyListTile({required this.onOpenPrivacyPolicy});

  final VoidCallback? onOpenPrivacyPolicy;

  static const String _enabledSupportingText =
      'View how Cow Bull Quest handles local data.';
  static const String _disabledSupportingText =
      'Available before public release.';

  @override
  Widget build(BuildContext context) {
    final enabled = onOpenPrivacyPolicy != null;
    final supportingText = enabled
        ? _enabledSupportingText
        : _disabledSupportingText;

    return Semantics(
      enabled: enabled,
      button: true,
      label: 'Privacy Policy. $supportingText',
      child: ExcludeSemantics(
        child: ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Privacy Policy'),
          subtitle: Text(supportingText),
          enabled: enabled,
          onTap: onOpenPrivacyPolicy,
        ),
      ),
    );
  }
}
