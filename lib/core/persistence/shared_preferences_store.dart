import 'package:shared_preferences/shared_preferences.dart';

import 'preferences_store.dart';

/// [PreferencesStore] backed by the real `shared_preferences` plugin.
///
/// Every method wraps the plugin call so a platform-channel failure surfaces
/// as a [PreferencesStoreException] rather than a bare, untyped exception or
/// a silently-ignored failure.
class SharedPreferencesStore implements PreferencesStore {
  const SharedPreferencesStore();

  @override
  Future<String?> getString(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (error) {
      throw PreferencesStoreException('failed to read "$key": $error');
    }
  }

  @override
  Future<void> setString(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wrote = await prefs.setString(key, value);
      if (!wrote) {
        throw PreferencesStoreException('failed to write "$key"');
      }
    } on PreferencesStoreException {
      rethrow;
    } catch (error) {
      throw PreferencesStoreException('failed to write "$key": $error');
    }
  }

  @override
  Future<void> remove(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final removed = await prefs.remove(key);
      if (!removed) {
        throw PreferencesStoreException('failed to remove "$key"');
      }
    } on PreferencesStoreException {
      rethrow;
    } catch (error) {
      throw PreferencesStoreException('failed to remove "$key": $error');
    }
  }
}
