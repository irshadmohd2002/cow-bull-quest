import '../../../core/time/local_date.dart';

/// Picks the Daily Challenge secret word for a given calendar date,
/// deterministically and entirely offline.
///
/// **Algorithm.** For a date and an [eligibleWords] pool, the secret word is
/// `eligibleWords[date.epochDay % eligibleWords.length]`, where
/// [LocalDate.epochDay] is the (never-negative, for any real calendar date)
/// number of whole days since 1970-01-01. This is:
/// - **Deterministic** — the same date and the same pool always produce the
///   same index; no randomness, no clock reads beyond the date itself.
/// - **Stable across runtimes** — plain integer arithmetic on a UTC day
///   count, unlike `String.hashCode`, which Dart explicitly does not
///   guarantee to be stable across processes, isolates, or platforms (VM vs.
///   web). This service never calls `.hashCode` on anything.
/// - **Offline** — no network access, no server-assigned puzzle; every
///   device with the same word-list version computes the same word for the
///   same date, independently.
///
/// **[eligibleWords] contract.** Callers (the app-level composition root)
/// must pass a stable, non-empty, already-deterministically-ordered word
/// list — in practice, `WordRepository.loadSecretWords` for
/// [wordLength]/[difficulty], whose backing generated asset
/// (`assets/generated/secret_words_common_4.txt`) is alphabetically sorted
/// and reproducible (see `docs/word_lists.md`). This service is pure and
/// feature-agnostic: it operates on a plain `List<String>`, not a
/// `WordRepository`, precisely so `daily_challenge` never has to import the
/// `game` feature (see CLAUDE.md's feature-isolation rule) — loading that
/// pool is the composition root's job.
///
/// **Versioning.** [wordListVersion] identifies which "generation" of the
/// eligible word list a computed secret word was drawn from. It is not an
/// input to the selection algorithm itself (the pool's content and order
/// already fully determine the mapping) — it exists purely as a stamp
/// recorded onto each `DailyChallengeResult` so a past completed result
/// stays interpretable even after a future app version changes the
/// underlying word-list asset (which would silently change what *future*
/// dates map to, without invalidating anything already recorded). Bump this
/// constant whenever `assets/generated/secret_words_common_4.txt` changes in
/// a way that would alter which word a previously-computed date maps to.
class DailyChallengeService {
  const DailyChallengeService();

  /// The current Daily Challenge word-list generation. See the class-level
  /// doc on when to bump this.
  static const int wordListVersion = 1;

  /// The secret-word length every Daily Challenge uses.
  static const int wordLength = 4;

  /// The number of valid guesses every Daily Challenge allows.
  static const int maxAttempts = 10;

  /// Deterministically selects the secret word for [date] from
  /// [eligibleWords].
  ///
  /// Throws [ArgumentError] if [eligibleWords] is empty — there is no word
  /// to select, and this should never happen with a real generated word-list
  /// asset (see `docs/word_lists.md`), so a caller hitting this indicates a
  /// genuine configuration problem rather than an expected runtime state.
  String secretWordFor(LocalDate date, List<String> eligibleWords) {
    if (eligibleWords.isEmpty) {
      throw ArgumentError.value(
        eligibleWords,
        'eligibleWords',
        'must not be empty',
      );
    }
    final index = date.epochDay % eligibleWords.length;
    return eligibleWords[index];
  }
}
