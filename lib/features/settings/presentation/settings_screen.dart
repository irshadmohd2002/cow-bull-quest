import 'package:flutter/material.dart';

import '../../../app_settings.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: RadioGroup<AppThemePreference>(
            groupValue: themePreference,
            onChanged: (selected) {
              if (selected != null) onThemePreferenceChanged(selected);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Text(
                    'Theme',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final preference in AppThemePreference.values)
                  RadioListTile<AppThemePreference>(
                    title: Text(_labels[preference]!),
                    value: preference,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
