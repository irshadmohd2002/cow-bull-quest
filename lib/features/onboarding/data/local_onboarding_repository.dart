import '../../../core/persistence/preferences_store.dart';
import '../../../core/persistence/storage_keys.dart';
import 'onboarding_repository.dart';

bool? _parseStoredBool(String? value) => switch (value) {
  'true' => true,
  'false' => false,
  _ => null,
};

/// [OnboardingRepository] backed by a [PreferencesStore], storing a single
/// `'true'`/`'false'` value under [StorageKeys.onboardingCompleted] — the
/// same simple boolean-flag pattern `AudioFeedbackSettings` uses for its own
/// preferences.
///
/// [loadCompleted] recovers safely — returning `null`, exactly like a
/// genuinely missing value — from every failure mode a corrupted or
/// unreadable install can produce: no stored value at all, an unrecognized
/// string, or a failed read. A malformed onboarding flag must never prevent
/// the app from starting.
class LocalOnboardingRepository implements OnboardingRepository {
  LocalOnboardingRepository({required PreferencesStore store})
    : _store = store; // ignore: prefer_initializing_formals

  final PreferencesStore _store;

  @override
  Future<bool?> loadCompleted() async {
    try {
      final stored = await _store.getString(StorageKeys.onboardingCompleted);
      return _parseStoredBool(stored);
    } on PreferencesStoreException {
      return null;
    }
  }

  @override
  Future<void> saveCompleted(bool completed) => _store.setString(
    StorageKeys.onboardingCompleted,
    completed ? 'true' : 'false',
  );

  @override
  Future<void> clear() => _store.remove(StorageKeys.onboardingCompleted);
}
