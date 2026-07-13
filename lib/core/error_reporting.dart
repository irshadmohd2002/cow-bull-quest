import 'dart:ui' show ErrorCallback;

import 'package:flutter/foundation.dart';

/// Installs this app's process-wide error hooks.
///
/// Covers exactly two sources, deliberately not a bootstrap failure (which
/// is handled locally by `AppStartup` instead, since only local code has
/// the context to offer a Retry/Reset UI — a global handler must never
/// attempt navigation):
///
/// - [FlutterError.onError]: framework errors raised during build, layout,
///   or paint. Logged via [FlutterError.dumpErrorToConsole]; Flutter's own
///   error widget still renders locally for the offending subtree and the
///   rest of the app keeps running.
/// - [PlatformDispatcher.onError]: errors thrown by async code with no
///   surrounding `try`/`catch` (e.g. an unawaited `Future` that rejects).
///   Logged, then swallowed (returns `true`) so a stray unhandled error
///   during a beta test can never take down the whole app.
///
/// Neither hook ever surfaces a stack trace or raw exception text to the
/// user, and neither adds a crash-reporting package — both just log. Safe
/// to call more than once: every call after the first is a no-op, so
/// `main()` calling this can never accidentally wrap the same handler
/// twice. Call [resetGlobalErrorHandlersForTest] in a test's `tearDown` to
/// restore whatever was installed before [installGlobalErrorHandlers] ran,
/// so one test file's global-handler replacement can never leak into
/// another test file.
void installGlobalErrorHandlers() {
  if (_installed) return;
  _installed = true;

  _previousFlutterOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };

  _previousPlatformOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('Unhandled async error: $error\n$stack');
    } else {
      debugPrint('Unhandled async error: ${error.runtimeType}');
    }
    return true;
  };
}

/// Restores whatever [FlutterError.onError] and
/// [PlatformDispatcher.instance.onError] were set to before
/// [installGlobalErrorHandlers] last ran, and allows a later
/// [installGlobalErrorHandlers] call to install again. Intended for test
/// `tearDown`; production code never needs to call this.
void resetGlobalErrorHandlersForTest() {
  if (!_installed) return;
  FlutterError.onError = _previousFlutterOnError;
  PlatformDispatcher.instance.onError = _previousPlatformOnError;
  _installed = false;
  _previousFlutterOnError = null;
  _previousPlatformOnError = null;
}

bool _installed = false;
FlutterExceptionHandler? _previousFlutterOnError;
ErrorCallback? _previousPlatformOnError;
