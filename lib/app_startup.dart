import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'app_bootstrap.dart';
import 'core/persistence/preferences_store.dart';
import 'core/persistence/shared_preferences_store.dart';
import 'theme/app_theme.dart';

/// [AppStartup]'s internal lifecycle. A sealed hierarchy so [AppStartup]
/// can exhaustively `switch` over exactly one source of truth, matching the
/// pattern [GameControllerState]/`StatisticsControllerState` already use
/// elsewhere in this app.
sealed class _StartupState {
  const _StartupState();
}

class _StartupLoading extends _StartupState {
  const _StartupLoading();
}

/// [error]/[stackTrace] are the raw values [AppStartup.loadBootstrap]
/// threw. Kept as the original typed values — never reduced to a message
/// string here — so presentation code decides how (and whether) to show
/// them; see [_showErrorDetails].
class _StartupFailure extends _StartupState {
  const _StartupFailure(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}

class _StartupReady extends _StartupState {
  const _StartupReady(this.bootstrap);

  final AppBootstrap bootstrap;
}

/// The app's real root widget: resolves [AppBootstrap] before showing
/// [CowBullApp], and never leaves the user on a blank screen if that
/// resolution fails.
///
/// Renders exactly one of three states: a plain loading screen while
/// [loadBootstrap] is in flight, a friendly failure screen with Retry and
/// Reset actions if it throws, or [CowBullApp] itself once it succeeds.
/// Every transition is a local `setState` — this widget never uses
/// `Navigator`, so startup recovery works even though no navigator (and no
/// [AppSettings]-backed theme) exists yet at this point in the app's
/// lifetime.
///
/// [loadBootstrap] and [resetStore] default to the real
/// [AppBootstrap.load]/[SharedPreferencesStore] the shipped app uses, and
/// exist as constructor-injected test seams — the same pattern
/// [CowBullApp] already uses for its own dependencies — so tests can force
/// a failing/recovering startup without touching real storage.
class AppStartup extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  AppStartup({
    super.key,
    Future<AppBootstrap> Function()? loadBootstrap,
    PreferencesStore? resetStore,
    this.debugShowErrorDetailsOverride,
  }) : loadBootstrap = loadBootstrap ?? AppBootstrap.load,
       resetStore = resetStore ?? const SharedPreferencesStore();

  final Future<AppBootstrap> Function() loadBootstrap;
  final PreferencesStore resetStore;

  /// Test-only seam overriding whether the failure screen shows raw error
  /// details. `null` (the production default) defers to [kDebugMode] —
  /// release builds never show raw exception text. Exists so a test can
  /// force either branch deterministically instead of depending on which
  /// mode `flutter test` happens to run under.
  @visibleForTesting
  final bool? debugShowErrorDetailsOverride;

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  _StartupState _state = const _StartupLoading();

  /// Guards [_load] against overlapping runs: set the instant a load
  /// starts, cleared once it settles. A second call while one is already
  /// in flight (e.g. a rapid double-tap on Retry, or [initState] racing an
  /// eager Retry) is a no-op rather than starting a second, concurrent
  /// [AppStartup.loadBootstrap] call.
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    setState(() => _state = const _StartupLoading());
    try {
      final bootstrap = await widget.loadBootstrap();
      if (!mounted) return;
      setState(() => _state = _StartupReady(bootstrap));
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() => _state = _StartupFailure(error, stackTrace));
    } finally {
      _loading = false;
    }
  }

  /// Shows a confirmation dialog, and — only if confirmed — clears
  /// exactly the app-owned keys [AppBootstrap.resetLocalData] removes,
  /// then retries [_load]. A reset failure (e.g. the same broken storage
  /// that caused the original startup failure) is non-fatal: [_load] runs
  /// regardless and simply re-surfaces whatever failure remains.
  ///
  /// [anchorContext] must be a descendant of the [MaterialApp]
  /// [_StartupFailureApp] builds — this state's own `context` sits above
  /// that `MaterialApp`, so it cannot supply the `Localizations`/`Navigator`
  /// ancestors [showDialog] requires.
  Future<void> _handleReset(BuildContext anchorContext) async {
    final confirmed = await showDialog<bool>(
      context: anchorContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset local data?'),
        content: const Text(
          'This clears your theme preference and statistics history so '
          'the app can start fresh. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    try {
      await AppBootstrap.resetLocalData(widget.resetStore);
    } catch (_) {
      // Swallowed deliberately: whether or not the reset itself succeeded,
      // _load() below is the single source of truth for whether the app
      // can now start — it will show a fresh failure screen if not.
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_state) {
      _StartupLoading() => const _StartupLoadingApp(),
      _StartupFailure(:final error, :final stackTrace) => _StartupFailureApp(
        error: error,
        stackTrace: stackTrace,
        busy: _loading,
        showDetails: widget.debugShowErrorDetailsOverride ?? kDebugMode,
        onRetry: () => unawaited(_load()),
        onReset: (context) => unawaited(_handleReset(context)),
      ),
      _StartupReady(:final bootstrap) => CowBullApp(
        settings: bootstrap.settings,
        statisticsRepository: bootstrap.statisticsRepository,
      ),
    };
  }
}

/// Shown while [AppStartup] is resolving [AppBootstrap]. Deliberately a
/// self-contained [MaterialApp] with the platform default theme — no
/// [AppSettings] has loaded yet at this point, so there is no persisted
/// theme preference to apply.
class _StartupLoadingApp extends StatelessWidget {
  const _StartupLoadingApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: Scaffold(
        body: Center(
          child: Semantics(
            label: 'Starting Cow Bull Quest.',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ExcludeSemantics(
                  child: Icon(Icons.track_changes, size: 40),
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when [AppStartup.loadBootstrap] throws. Always shows a generic,
/// user-friendly message; [showDetails] additionally reveals [error]/
/// [stackTrace] verbatim behind a collapsed section — true only in debug
/// builds (or when a test forces it), never in a release build a tester
/// could see.
class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp({
    required this.error,
    required this.stackTrace,
    required this.busy,
    required this.showDetails,
    required this.onRetry,
    required this.onReset,
  });

  final Object error;
  final StackTrace stackTrace;
  final bool busy;
  final bool showDetails;
  final VoidCallback onRetry;

  /// Receives a [BuildContext] descended from the [MaterialApp] built
  /// below — [showDialog] needs a `Localizations`/`Navigator` ancestor
  /// that only exists inside that `MaterialApp`, not on whatever context
  /// [AppStartup] itself was built with.
  final void Function(BuildContext context) onReset;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: Scaffold(
        // A Builder, not this method's own `context`, is required here:
        // `onReset` calls `showDialog`, which needs a `Localizations`/
        // `Navigator` ancestor — this method's own `context` sits above the
        // `MaterialApp` returned below, but a `Builder`'s context is a
        // genuine descendant of it.
        body: Builder(
          builder: (context) => SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Cow Bull Quest couldn't start",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Try again, or reset local app data if the problem '
                      'continues.',
                      textAlign: TextAlign.center,
                    ),
                    if (showDetails) ...[
                      const SizedBox(height: 16),
                      ExpansionTile(
                        title: const Text('Details (debug only)'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text('$error\n$stackTrace'),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton(
                          onPressed: busy ? null : () => onReset(context),
                          child: const Text('Reset local data'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: busy ? null : onRetry,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
