import 'dart:async';

import 'package:cowbullgame/core/persistence/preferences_store.dart';

/// In-memory [PreferencesStore] fake so tests can exercise persistence
/// behavior without platform channels.
///
/// [failGetString], [failSetString], and [failRemove] let a test force the
/// next call to that method to throw [PreferencesStoreException], so
/// write-failure and read-failure handling can be exercised deterministically.
///
/// [getStringGate], if set, makes every [getString] call await it before
/// returning — lets a test force worst-case interleaving between two
/// concurrent callers (e.g. to prove a repository actually serializes
/// operations, rather than merely happening to run in order).
///
/// [setStringDelays], if a value being written has a matching entry, makes
/// that [setString] call finish only after the given [Duration] — lets a
/// test force a "reverse completion order" (e.g. an earlier write finishing
/// after a later one would, if nothing serialized them) to prove a caller
/// actually queues writes rather than merely happening to complete them in
/// order.
class FakePreferencesStore implements PreferencesStore {
  FakePreferencesStore({Map<String, String>? initialValues})
    : _values = {...?initialValues};

  final Map<String, String> _values;

  /// Every key ever passed to [setString], in call order (including repeats).
  final List<String> setStringCalls = [];

  bool failGetString = false;
  bool failSetString = false;
  bool failRemove = false;

  Completer<void>? getStringGate;
  final Map<String, Duration> setStringDelays = {};

  /// Direct read access for test assertions, bypassing the interface.
  Map<String, String> get values => Map.unmodifiable(_values);

  @override
  Future<String?> getString(String key) async {
    final gate = getStringGate;
    if (gate != null) await gate.future;
    if (failGetString) {
      throw const PreferencesStoreException('forced getString failure');
    }
    return _values[key];
  }

  @override
  Future<void> setString(String key, String value) async {
    setStringCalls.add(key);
    final delay = setStringDelays[value];
    if (delay != null && delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (failSetString) {
      throw const PreferencesStoreException('forced setString failure');
    }
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    if (failRemove) {
      throw const PreferencesStoreException('forced remove failure');
    }
    _values.remove(key);
  }
}
