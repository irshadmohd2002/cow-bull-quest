# CLAUDE.md

Guidance for anyone (human or AI) working on this repository. Read this before
adding code.

## What this project is

CowBullGame is a cross-platform Flutter implementation of **Bulls and Cows**
played with words instead of digits: the player guesses a secret word and
gets feedback per guess — a **bull** for a letter that's correct and in the
right position, a **cow** for a letter that's correct but in the wrong
position. `assets/source` holds the raw dictionaries (`words_alpha.txt`, a
~370k-word English list, and `google-10000-english.txt`, a 10k common-word
frequency list) that back word selection and guess validation.

Targets: Android, iOS, Web, Windows, macOS, Linux (all scaffolded already).

## Architecture

Feature-first: feature-specific models, services, repositories, controllers,
and data access live **inside the owning feature by default**. The
top-level shared folders (`models/`, `services/`, `data/`) exist only for
code that is genuinely reused by two or more features — they start empty and
stay empty until real reuse justifies moving something into them. Most game
logic will begin, and often stay, inside `features/game/`.

```
lib/
  core/       cross-cutting building blocks with no feature knowledge:
              constants, exceptions/failure types, base classes/interfaces,
              app-wide extension methods. No dependency-injection framework
              is chosen yet — add one only if a feature's wiring genuinely
              needs it, same rule as state management below.
  features/   one folder per feature/screen. Each feature owns everything
              specific to it: models, services, repositories/data access,
              controllers, timers/game-specific logic, and its screens
              (typically under a presentation/ subfolder). Example:

                features/
                  game/
                    data/          # e.g. WordRepository, asset loading/parsing
                    models/        # e.g. Guess, GuessResult, GameState
                    services/      # e.g. GuessScorer, turn/game-state rules
                    presentation/  # screens + feature-local widgets
                  home/
                    presentation/

              Guess, GuessResult, GameState, GuessScorer, and WordRepository
              are game-specific today, so they start under features/game/ —
              they only move to a top-level shared folder once a second
              feature genuinely needs the same thing. Likewise, timers and
              other game-specific mechanics (a countdown, animation
              sequencing, etc.) stay feature-local under features/game/
              unless they become genuinely reusable elsewhere.
  models/     shared plain data classes used by 2+ features. No Flutter
              imports. Empty until something is actually shared — e.g.
              DifficultyOption, which the home feature exposes as a
              difficulty selection and the app-level composition root maps
              onto the game feature's own GameDifficulty, so home never has
              to import the game feature just to offer a difficulty choice.
  services/   shared business logic used by 2+ features, as plain Dart
              classes. Depends on shared models/core and on repositories
              exposed by data/ — never does file/asset I/O directly, never
              imports Flutter widgets. Empty until something is actually
              shared.
  data/       shared data-access layer (loading/parsing assets, persistence
              I/O) used by 2+ features, exposed through repositories. All
              shared I/O and parsing lives here, not in shared services or
              in features. Empty until something is actually shared.
  widgets/    small, reusable, presentation-only widgets used by 2+ features
              (buttons, dialogs, tiles). Feature-specific widgets stay inside
              that feature's own presentation/ folder.
  theme/      ThemeData, color palettes, text styles, spacing constants.
  routes/     navigation glue — see Navigation below; kept empty and
              implementation-neutral until a navigation strategy is chosen.
  utils/      small stateless helpers (formatting, validators, random
              helpers) that aren't a core abstraction and aren't a game rule.
```

**Dependency rule:** features must not import other features directly.
Feature code may depend on shared code (`core/`, `models/`, `services/`,
`data/`, `widgets/`, `theme/`, `routes/`, `utils/`). Shared code must never
depend on feature code. The only way something reaches a shared folder is by
being extracted out of the feature that first needed it, once a second
feature genuinely needs it too — shared folders are not the default starting
point for new code.

`lib/main.dart` should stay minimal — its job is to call `runApp()`. As
gameplay lands, the current `MyApp`/`MyHomePage` boilerplate moves into
`lib/app.dart` and `lib/features/home/presentation/`.

### State management

No state-management package is added yet. Default to `setState` for local,
ephemeral UI state that a single widget owns (a toggle, an animation, a text
field); use a plain `ChangeNotifier` only for state that must be shared
across widgets or holds real logic. Keep game rules (scoring, validation) in
plain, non-Flutter classes under `services/` so they're unit-testable
without pumping widgets. Only reach for a state-management package (e.g.
`provider`) if a concrete feature's complexity genuinely needs it — justify
it in the PR that adds it, don't add it speculatively.

### Navigation

No navigation strategy is chosen yet — plain `Navigator` push/pop, named
routes, and router packages are all still open options. `lib/routes/` is
reserved for whatever that becomes, decided when there are actually enough
screens to need one. Don't pre-build route-name constants or route-generation
scaffolding ahead of that decision; a feature can `Navigator.push` its own
screens directly in the meantime.

### Assets pipeline

`assets/source/` holds raw, unmodified dictionaries. `assets/generated/` holds
derived word lists (e.g. filtered by length, deduplicated, frequency-ranked)
produced by a script in `scripts/`. Never hand-edit files in
`assets/generated/` — regenerate them from source instead by running
`dart run scripts/generate_word_lists.dart`; see `docs/word_lists.md` for
the full pipeline.

## Coding standards

- Follow `flutter_lints` (already enabled in `analysis_options.yaml`); code
  must pass `flutter analyze` with zero warnings before merge.
- Prefer composition over large files — a widget/class doing multiple
  unrelated things should be split.
- Keep any `models/` and `services/` folder — feature-local or shared — free
  of `package:flutter` imports so game logic can be unit-tested without a
  widget tester.
- Public classes and non-trivial public methods get a one-line `///` doc
  comment describing intent, not mechanics. Skip comments where the name
  already says it.
- No unnecessary dependencies — justify any new package in the PR/commit
  description (what it replaces doing by hand, and why that's worth it).
- Immutable data classes for models (`final` fields, `const` constructors
  where possible).
- Handle errors at the layer that can act on them; don't swallow exceptions
  silently. Surface failures from `services`/`data` as typed exceptions or
  result types defined in `core`, and let `features` decide how to present
  them — never a bare `print`/empty `catch`.
- Treat accessibility as a baseline, not an afterthought: meaningful
  `Semantics`/labels on interactive widgets, respect system text-scaling,
  and never convey game feedback (bulls/cows) by color alone.

## Naming conventions

- Files: `snake_case.dart`, matching the primary class they export
  (`guess_result.dart` exports `GuessResult`).
- Classes/enums/typedefs: `UpperCamelCase`.
- Members, variables, functions: `lowerCamelCase`.
- Private members: leading underscore (`_secretWord`).
- Test files mirror the file under test with a `_test.dart` suffix, in the
  matching path under `test/` (see below).
- Feature folders are named after the feature, singular and lowercase
  (`features/game`, not `features/games` or `features/Game`).

## File organization

- One public top-level class per file, generally.
- `test/` mirrors `lib/` folder-for-folder, including inside features:
  `lib/features/game/services/guess_scorer.dart` →
  `test/features/game/services/guess_scorer_test.dart`. Pure logic gets fast
  unit tests; only widget-facing behavior needs `testWidgets`.
- Barrel files (`*.dart` re-exporting a folder) are only added once a folder
  has enough call sites to justify one — don't pre-create them.

## Workflow for future development

1. Before adding gameplay code, confirm which feature it belongs to. Default
   to putting it inside that feature's own `models`/`services`/`data`/
   `presentation`; only place it in a top-level shared folder if it's
   already used by, or clearly needed by, a second feature.
2. Within the feature, add/extend models first, then services (business
   logic, unit-tested), then the presentation/ UI that consumes them.
3. Run `flutter analyze` and `flutter test` before considering work done.
4. Only touch `pubspec.yaml` when a change genuinely requires it; explain why
   in the commit.
5. Keep this file up to date when architecture decisions change — it's the
   source of truth for how the project is organized, not a one-time note.
