import '../exceptions.dart';

/// Thrown when a [PreferencesStore] operation fails.
class PreferencesStoreException extends AppException {
  const PreferencesStoreException(super.message);
}

/// Minimal local key-value storage abstraction for string preferences.
///
/// App code and features depend on this interface rather than on a specific
/// storage package directly, so the concrete storage mechanism stays
/// swappable and tests can use an in-memory fake with no platform channels.
/// Exposes only the operations this app actually needs: reading, writing,
/// and removing string values.
abstract class PreferencesStore {
  /// Returns the stored string for [key], or `null` if nothing is stored.
  ///
  /// Throws [PreferencesStoreException] if the underlying storage fails.
  Future<String?> getString(String key);

  /// Stores [value] under [key], overwriting any existing value.
  ///
  /// Throws [PreferencesStoreException] if the write fails. Callers must not
  /// treat a thrown write as having succeeded.
  Future<void> setString(String key, String value);

  /// Removes any value stored under [key]. Does nothing if [key] is absent.
  ///
  /// Throws [PreferencesStoreException] if the removal fails.
  Future<void> remove(String key);
}
