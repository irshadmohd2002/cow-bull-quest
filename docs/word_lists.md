# Word lists

How CowBullGame turns raw English word lists into the game-ready word lists
it ships and loads at runtime.

## Source dictionaries

`assets/source/` holds two raw, unmodified dictionaries. They are build-time
inputs only — the app never reads them at runtime, and they must never be
hand-edited.

- `words_alpha.txt` — a broad (~370k word) English word list. Source for
  **allowed guesses**: anything a player types that matches a real word
  should be accepted, even an obscure one.
- `google-10000-english.txt` — a list of the 10,000 most common English
  words, **ordered from most to least common**. Source for **secret
  words**: the word the player is trying to guess should be a word an
  average player has a reasonable chance of knowing, not an obscure
  dictionary entry. Its line order is also the sole ranking signal used to
  assign secret words to a difficulty tier (see below).

### Allowed guesses vs. secret words

These are deliberately different lists:

- **Allowed words** (`allowed_words_<n>.txt`) — every word of length `n`
  the game will accept as a valid guess. Derived from `words_alpha.txt`.
  Large and permissive by design. **Shared across every difficulty** —
  allowed-guess validation never depends on difficulty.
- **Secret words** (`secret_words_<difficulty>_<n>.txt`) — the smaller,
  difficulty-specific pool the game picks the target word from. Derived
  from `google-10000-english.txt`. Small and common by design, and always
  a subset of the allowed-word list for the same length (see below) — a
  player must always be able to correctly guess the secret word.

## Supported lengths

This milestone supports secret/guess words of exactly **4, 5, and 6**
letters. See "Extending supported lengths" below to add more later.

## Difficulty

Milestone 7 adds three difficulty tiers. Difficulty affects **only** which
secret-word pool a game's secret word is drawn from — it never changes
scoring, allowed-guess validation, duplicate-letter behavior, or attempt
limits.

- **Easy** — the most frequent quarter of ranked secret-word candidates:
  familiar, high-frequency words.
- **Common** — the middle half of ranked secret-word candidates: broader
  everyday vocabulary.
- **Hard** — the least frequent quarter of ranked secret-word candidates:
  less frequent words.

### Ranking source

For each supported word length, the eligible secret-word candidates (see
"Filtering rules" below) are kept in **frequency-rank order**: the order
they first appear in `google-10000-english.txt`, most common first. This
order is preserved through filtering and is the only input to the
difficulty partition — it is discarded (replaced by alphabetical order) only
in the final written files, since runtime assets must be sorted.

### Partition thresholds

Given `n` eligible, frequency-ranked candidates for a word length, and
`quarter = n ~/ 4` (integer division):

- **Easy** = the first `quarter` candidates (indices `0` to `quarter - 1`)
  — the most frequent.
- **Hard** = the last `quarter` candidates (indices `n - quarter` to
  `n - 1`) — the least frequent.
- **Common** = everything in between (`n - 2 * quarter` candidates) — the
  middle half, plus any remainder left over from the integer division. This
  means Common is never smaller than Easy or Hard, and is exactly half of
  `n` only when `n` is divisible by 4.

Easy, Common, and Hard are therefore always disjoint, and their union is
always exactly the full eligible candidate set for that word length. The
split is implemented by the pure function `partitionByDifficulty` in
`scripts/generate_word_lists.dart`, which is unit-tested directly in
`test/scripts/generate_word_lists_test.dart`.

A pool is flagged in the generator's summary output if it falls below
`minimumPoolSize` (50 words) — a reporting threshold only, meant to catch a
word length whose difficulty pools would be impractically small for
gameplay variety. Generation only fails outright if a pool is completely
empty, since an empty generated file is unusable at runtime. In practice,
current source data yields pools in the hundreds for every length/difficulty
combination — see the generator's own summary output for exact counts.

## Filtering rules

Both source files go through the same normalization before length
filtering and output:

1. Trim whitespace and lowercase.
2. Keep only entries matching `^[a-z]+$` (ASCII letters only — rejects
   entries with digits, punctuation, apostrophes, or spaces).
3. Keep only entries whose length is one of the supported lengths.
4. Deduplicate (keeping the first occurrence for the frequency-ranked
   secret source; order doesn't matter for the alphabetically-sorted
   allowed source).

For the secret-word lists, one more rule applies before difficulty
partitioning:

5. Keep only entries that also appear in the allowed-word list of the same
   length. A common word absent from the filtered allowed-word set is
   excluded from the secret-word candidates; the generation script reports
   how many words were excluded this way, per length.

Every generated file is therefore: one lowercase `a-z`-only word per line,
of the exact target length, deduplicated, **sorted alphabetically** (for
storage — see "Ranking source" above for why secret words are ranked
differently before partitioning), with no blank lines, ending in a trailing
newline.

## Generated files

Produced under `assets/generated/` — **never hand-edit these**; they are
build artifacts and must always be reproducible by rerunning the
generator:

```
assets/generated/allowed_words_4.txt
assets/generated/allowed_words_5.txt
assets/generated/allowed_words_6.txt

assets/generated/secret_words_easy_4.txt
assets/generated/secret_words_easy_5.txt
assets/generated/secret_words_easy_6.txt

assets/generated/secret_words_common_4.txt
assets/generated/secret_words_common_5.txt
assets/generated/secret_words_common_6.txt

assets/generated/secret_words_hard_4.txt
assets/generated/secret_words_hard_5.txt
assets/generated/secret_words_hard_6.txt
```

The pre-milestone-7 generic `secret_words_<n>.txt` files (undifferentiated
by difficulty) are obsolete and no longer generated; the generator deletes
them if it finds them left over from a previous run.

Only `assets/generated/` is registered in `pubspec.yaml` for runtime use;
`assets/source/` is not bundled with the app.

## Regenerating

Run from the repository root:

```
dart run scripts/generate_word_lists.dart
```

The script reads both source files, applies the filtering and
difficulty-partitioning rules above, writes all twelve generated files,
verifies its own output (format, length, sort order, uniqueness, the
secret-is-subset-of-allowed property, and that the three difficulty pools
per length are disjoint), and prints a summary of source line counts,
output counts, duplicates removed, invalid entries removed, common words
excluded per length, and the size of each of the nine secret-word pools
(flagging any pool below the minimum reporting threshold). It exits with a
non-zero status and a clear message if a source file is missing or
unreadable, or if a difficulty pool for a supported length would be empty.
The script uses only Dart standard libraries.

The script is **deterministic**: rerunning it against unchanged source
files reproduces byte-identical output, since difficulty partitioning
depends only on file content and list order/length — never on randomness,
timestamps, or external state.

The script's pure logic — normalization, ranking, eligibility filtering,
and difficulty partitioning — is factored into top-level functions (not
gated behind `main()`) specifically so `test/scripts/generate_word_lists_test.dart`
can unit-test them directly, without repeatedly shelling out to the script.

## Extending supported lengths later

The generator is driven entirely by the `supportedLengths` constant at the
top of `scripts/generate_word_lists.dart`. To add a new length:

1. Add the length to `supportedLengths`.
2. Rerun the generator — it will produce the new `allowed_words_<n>.txt`
   and all three `secret_words_<difficulty>_<n>.txt` files automatically.
3. Add the new length to `WordRepository.supportedLengths` in
   `lib/features/game/data/word_repository.dart` so the repository layer
   accepts it.

No other change to the filtering or partitioning logic is needed — every
step in the script already operates per-length off that one list.

## Source provenance and licensing

`words_alpha.txt` and `google-10000-english.txt` were already present in
this repository's `assets/source/` when this pipeline was built; this
document makes no claim about their license or redistribution terms, and
frequency ranking derived from `google-10000-english.txt` is not a claim of
rigorous linguistic curation — it is a simple, deterministic proxy for
"familiar vs. less familiar," nothing more. Their provenance and licensing
must be verified — and, if necessary, replaced with dictionaries under
confirmed compatible licenses — before any public release of this app.
