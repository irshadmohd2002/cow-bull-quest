/// Local persistence for whether the player has completed (or skipped)
/// first-launch onboarding.
///
/// Implementations must never let malformed stored data propagate as an
/// exception from [loadCompleted] — see `LocalOnboardingRepository` — since
/// a corrupted value must never prevent the app from starting or trap the
/// player on a broken screen. [saveCompleted] may throw; callers must treat
/// a persistence failure as non-fatal, exactly like `StreakRepository`/
/// `CoinWallet` already do for their own writes.
abstract class OnboardingRepository {
  /// Loads whether onboarding has been completed, or `null` if nothing has
  /// ever been recorded (including a fresh install, and safe recovery from
  /// malformed stored data) — the ambiguous case `OnboardingController.load`
  /// resolves using its own existing-install signal.
  Future<bool?> loadCompleted();

  /// Persists [completed], overwriting whatever was previously stored.
  Future<void> saveCompleted(bool completed);

  /// Permanently deletes the stored value. Never touches any other
  /// persisted preference. Used by `AppBootstrap.resetLocalData` so a full
  /// data reset also restores first-launch onboarding behavior.
  Future<void> clear();
}
