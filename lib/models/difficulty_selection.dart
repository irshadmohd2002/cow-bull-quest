/// The difficulty a player can choose on the home screen before starting a
/// game.
///
/// Lives in this shared `models/` layer (see CLAUDE.md) — rather than the
/// `game` feature's own `GameDifficulty` — because it is used by two
/// places: the `home` feature, which shows it as a selectable option, and
/// the app-level composition root, which maps it onto `GameDifficulty` when
/// building a `GameConfig`. Keeping this enum here, with no game behavior
/// and no human-facing text of its own, means `home` never needs to import
/// the `game` feature just to offer a difficulty choice. Presentation code
/// owns how each value is labeled and described.
enum DifficultyOption { easy, common, hard }
