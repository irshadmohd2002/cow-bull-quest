import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Applies to every test file under `test/` automatically (this is a
/// magic filename `package:flutter_test` looks for) — installs mock
/// handlers for the raw platform channels `package:audioplayers` talks to
/// before any test runs, so constructing a real `AudioPlayer` (as
/// `AudioPlayersAudioService` — and therefore `AppBootstrap.load`,
/// `CowBullApp`'s uninjected fallback, and anything else that builds one
/// off the shipped, real audio stack — always does) never throws a
/// [MissingPluginException] purely from being constructed in a test
/// environment with no real platform.
///
/// This app's own code never calls these channels directly; every call
/// goes through `AudioService`/`HapticService`, and no test in this suite
/// asserts anything about what these mocked responses are — the milestone
/// requirement is that automated tests never play real audio, which fake
/// `AudioService`/`HapticService` implementations already guarantee for
/// every unit/widget test that constructs its own dependencies explicitly.
/// This file exists solely so the handful of tests that exercise the real,
/// production composition (`AppBootstrap`, `CowBullApp`'s fallback) don't
/// fail on an unrelated, environment-only platform-channel gap.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  const globalChannel = MethodChannel('xyz.luan/audioplayers.global');
  const playerChannel = MethodChannel('xyz.luan/audioplayers');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(globalChannel, (call) async => null);
  messenger.setMockMethodCallHandler(playerChannel, (call) async => null);

  await testMain();
}
