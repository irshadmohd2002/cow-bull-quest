import 'package:flutter/material.dart';

import '../../../app_settings.dart';
import '../../../theme/app_spacing.dart';

/// Lets the player choose the app's theme preference.
///
/// Purely presentational: it does not own [AppThemePreference] state itself
/// and imports no `home` or `game` feature file. It receives the
/// currently-selected [themePreference] and reports every selection through
/// [onThemePreferenceChanged]; the app-level composition root owns the
/// actual [AppSettings] instance and decides what happens with the change.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.themePreference,
    required this.onThemePreferenceChanged,
  });

  /// The currently-selected theme preference.
  final AppThemePreference themePreference;

  /// Called with the newly-selected preference whenever the player picks a
  /// different option.
  final ValueChanged<AppThemePreference> onThemePreferenceChanged;

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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
