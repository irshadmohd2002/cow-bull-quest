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
  words. Source for **secret words**: the word the player is trying to
  guess should be a word an average player has a reasonable chance of
  knowing, not an obscure dictionary entry.

### Allowed guesses vs. secret words

These are deliberately different lists:

- **Allowed words** (`allowed_words_<n>.txt`) — every word of length `n`
  the game will accept as a valid guess. Derived from `words_alpha.txt`.
  Large and permissive by design.
- **Secret words** (`secret_words_<n>.txt`) — the smaller pool the game
  picks the target word from. Derived from `google-10000-english.txt`.
  Small and common by design, and always a subset of the allowed-word list
  for the same length (see below) — a player must always be able to
  correctly guess the secret word.

## Supported lengths

This milestone supports secret/guess words of exactly **4, 5, and 6**
letters. See "Extending supported lengths" below to add more later.

## Filtering rules

Both source files go through the same normalization before length
filtering and output:

1. Trim whitespace and lowercase.
2. Keep only entries matching `^[a-z]+$` (ASCII letters only — rejects
   entries with digits, punctuation, apostrophes, or spaces).
3. Keep only entries whose length is one of the supported lengths.
4. Deduplicate.
5. Sort alphabetically.

For the secret-word lists, one more rule applies:

6. Keep only entries that also appear in the allowed-word list of the same
   length. A common word absent from the filtered allowed-word set is
   excluded from the secret-word output; the generation script reports how
   many words were excluded this way, per length.

Every generated file is therefore: one lowercase `a-z`-only word per line,
of the exact target length, deduplicated, sorted alphabetically, with no
blank lines, ending in a trailing newline.

## Generated files

Produced under `assets/generated/` — **never hand-edit these**; they are
build artifacts and must always be reproducible by rerunning the
generator:

```
assets/generated/allowed_words_4.txt
assets/generated/allowed_words_5.txt
assets/generated/allowed_words_6.txt
assets/generated/secret_words_4.txt
assets/generated/secret_words_5.txt
assets/generated/secret_words_6.txt
```

Only `assets/generated/` is registered in `pubspec.yaml` for runtime use;
`assets/source/` is not bundled with the app.

## Regenerating

Run from the repository root:

```
dart run scripts/generate_word_lists.dart
```

The script reads both source files, applies the filtering rules above,
writes all six generated files, verifies its own output (format, length,
sort order, uniqueness, and the secret-is-subset-of-allowed property), and
prints a summary of source line counts, output counts, duplicates removed,
invalid entries removed, and common words excluded per length. It exits
with a non-zero status and a clear message if a source file is missing or
unreadable. The script uses only Dart standard libraries.

The script is deterministic: rerunning it against unchanged source files
reproduces byte-identical output.

## Extending supported lengths later

The generator is driven entirely by the `supportedLengths` constant at the
top of `scripts/generate_word_lists.dart`. To add a new length:

1. Add the length to `supportedLengths`.
2. Rerun the generator — it will produce the new `allowed_words_<n>.txt`
   and `secret_words_<n>.txt` files automatically.
3. Add the new length to `WordRepository.supportedLengths` in
   `lib/features/game/data/word_repository.dart` so the repository layer
   accepts it.

No other change to the filtering logic is needed — every step in the
script already operates per-length off that one list.

## Source provenance and licensing

`words_alpha.txt` and `google-10000-english.txt` were already present in
this repository's `assets/source/` when this pipeline was built; this
document makes no claim about their license or redistribution terms. Their
provenance and licensing must be verified — and, if necessary, replaced
with dictionaries under confirmed compatible licenses — before any public
release of this app.
