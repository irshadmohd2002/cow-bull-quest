import 'package:cowbullgame/core/error_reporting.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Every test in this file replaces process-wide error hooks. Restoring
  // them here — regardless of which test just ran — is what keeps this
  // file's global-handler replacement from leaking into every other test
  // file's own error handling (in particular flutter_test's own
  // FlutterError.onError, which powers `tester.takeException()`).
  tearDown(resetGlobalErrorHandlersForTest);

  test('installs a FlutterError.onError handler', () {
    installGlobalErrorHandlers();
    expect(FlutterError.onError, isNotNull);
  });

  test('installs a PlatformDispatcher.onError handler', () {
    installGlobalErrorHandlers();
    expect(PlatformDispatcher.instance.onError, isNotNull);
  });

  test('a second call is idempotent — it does not replace the installed '
      'handlers', () {
    installGlobalErrorHandlers();
    final flutterHandlerAfterFirst = FlutterError.onError;
    final platformHandlerAfterFirst = PlatformDispatcher.instance.onError;

    installGlobalErrorHandlers();

    expect(FlutterError.onError, same(flutterHandlerAfterFirst));
    expect(
      PlatformDispatcher.instance.onError,
      same(platformHandlerAfterFirst),
    );
  });

  test('the installed FlutterError handler captures an error without '
      'rethrowing it', () {
    installGlobalErrorHandlers();
    final details = FlutterErrorDetails(
      exception: StateError('a framework error'),
      stack: StackTrace.current,
    );

    expect(() => FlutterError.onError!(details), returnsNormally);
  });

  test('the installed PlatformDispatcher handler returns true so an uncaught '
      'async error does not crash the app', () {
    installGlobalErrorHandlers();

    final handled = PlatformDispatcher.instance.onError!(
      StateError('an unhandled async error'),
      StackTrace.current,
    );

    expect(handled, isTrue);
  });

  test('resetGlobalErrorHandlersForTest restores whatever was installed '
      'before installGlobalErrorHandlers ran', () {
    void sentinelFlutterHandler(FlutterErrorDetails details) {}
    bool sentinelPlatformHandler(Object error, StackTrace stack) => true;

    FlutterError.onError = sentinelFlutterHandler;
    PlatformDispatcher.instance.onError = sentinelPlatformHandler;

    installGlobalErrorHandlers();
    expect(FlutterError.onError, isNot(same(sentinelFlutterHandler)));

    resetGlobalErrorHandlersForTest();

    expect(FlutterError.onError, same(sentinelFlutterHandler));
    expect(PlatformDispatcher.instance.onError, same(sentinelPlatformHandler));
  });

  test('after a reset, installGlobalErrorHandlers can install again', () {
    installGlobalErrorHandlers();
    final firstInstall = FlutterError.onError;

    resetGlobalErrorHandlersForTest();
    installGlobalErrorHandlers();

    expect(FlutterError.onError, isNot(same(firstInstall)));
    expect(FlutterError.onError, isNotNull);
  });

  test('resetting without a prior install is a no-op that does not throw', () {
    expect(resetGlobalErrorHandlersForTest, returnsNormally);
  });
}
