import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/onboarding_repository.dart';

/// App-wide, in-memory "has the player completed first-launch onboarding"
/// state shared by the whole `MaterialApp`.
///
/// Extends [ChangeNotifier] — the same pattern `AppSettings`/`CoinWallet`/
/// `StreakController` use for shared, observable state per this project's
/// state-management guidance (see CLAUDE.md). [CowBullApp] owns one
/// instance for the app's lifetime and disposes it; while [completed] is
/// `false`, the composition root shows `OnboardingScreen` in place of the
/// normal Home screen (see `app.dart`).
///
/// **Existing-install migration.** A missing stored value is ambiguous: it
/// means either a genuinely fresh install (onboarding should show) or an
/// installation that ran an app version older than Milestone 20, which
/// never wrote this key at all (onboarding should *not* suddenly appear for
/// a player who already knows the app). [load] resolves that ambiguity
/// using [treatAsCompletedIfMissing], which the app-level composition root
/// derives from a reliable existing-install signal — whether a coin balance
/// was already persisted (see `AppBootstrap.load`) — rather than guessing
/// here. See `AppBootstrap.load`'s own doc for exactly how that signal is
/// captured before it could be overwritten by this same bootstrap.
class OnboardingController extends ChangeNotifier {
  OnboardingController({
    required bool initialCompleted,
    OnboardingRepository? repository,
  }) : _completed = initialCompleted,
       _repository = repository; // ignore: prefer_initializing_formals

  /// Loads the persisted onboarding-completed flag from [repository] —
  /// falling back to [treatAsCompletedIfMissing] if nothing is stored, the
  /// stored value is unrecognized, or reading fails — and returns an
  /// [OnboardingController] seeded with the result that persists future
  /// changes back to the same [repository].
  ///
  /// A genuinely stored value (`true` or `false`) is always restored
  /// verbatim regardless of [treatAsCompletedIfMissing] — that fallback only
  /// ever applies to the *first* time this app version ever resolves the
  /// flag for this install.
  static Future<OnboardingController> load({
    required OnboardingRepository repository,
    required bool treatAsCompletedIfMissing,
  }) async {
    bool completed;
    try {
      completed = await repository.loadCompleted() ?? treatAsCompletedIfMissing;
    } catch (_) {
      completed = treatAsCompletedIfMissing;
    }
    return OnboardingController(
      initialCompleted: completed,
      repository: repository,
    );
  }

  final OnboardingRepository? _repository;
  bool _completed;
  bool _disposed = false;

  /// Whether the player has completed or skipped first-launch onboarding.
  bool get completed => _completed;

  /// The error thrown by the most recent persistence attempt, or `null` if
  /// none has failed. Exposed only so tests can assert a write was actually
  /// attempted and failed; a failed persistence write is non-fatal — the
  /// in-memory flag keeps applying regardless, mirroring `AppSettings`.
  @visibleForTesting
  Object? get debugLastPersistError => _lastPersistError;
  Object? _lastPersistError;

  Future<void> _persistTail = Future<void>.value();

  /// Marks onboarding as completed (via Finish) or skipped — both are the
  /// same outcome: the player will not see it again automatically. Does
  /// nothing if already completed, or if this instance has already been
  /// [dispose]d, so re-finishing an already-completed manual "View Tutorial"
  /// replay never re-notifies listeners or re-persists a value that is
  /// already correct.
  void markCompleted() {
    if (_disposed || _completed) return;
    _completed = true;
    notifyListeners();
    unawaited(_enqueuePersist(true));
  }

  Future<void> _enqueuePersist(bool completed) {
    final result = _persistTail.then((_) => _persist(completed));
    _persistTail = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<void> _persist(bool completed) async {
    final repository = _repository;
    if (repository == null) return;
    try {
      await repository.saveCompleted(completed);
      _lastPersistError = null;
    } catch (error) {
      _lastPersistError = error;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
