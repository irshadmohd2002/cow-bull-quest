import 'dart:async';

import 'package:flutter/foundation.dart';

import 'core/persistence/preferences_store.dart';
import 'core/persistence/storage_keys.dart';

/// The coin balance a player has the first time this app version
/// initializes the coin wallet — i.e. whenever nothing has ever been
/// persisted under [StorageKeys.coinBalance]. Never re-applied to an
/// already-initialized balance, no matter its value.
const int startingCoinBalance = 100;

/// App-wide, in-memory coin balance shared by the whole `MaterialApp`.
///
/// Extends [ChangeNotifier] — the same pattern `AppSettings` and
/// `StatisticsController` use for shared, observable state per this
/// project's state-management guidance (see CLAUDE.md). [CowBullApp] owns
/// one instance for the app's lifetime and disposes it; `GameController`
/// receives the same instance so hint purchases spend from (and are
/// reflected by) the one shared balance the Home and Game screens both
/// display.
///
/// Coins are never redeemable for anything real — this class has no notion
/// of purchases, real-money value, or "cash". [spend] is the only way the
/// balance ever decreases; nothing in this milestone increases it once
/// initialized.
///
/// If a [PreferencesStore] is supplied, every successful [spend] is
/// persisted to it under [StorageKeys.coinBalance] after updating in-memory
/// state and notifying listeners; a persistence failure never reverts the
/// already-applied in-memory deduction — coins already spent stay spent for
/// the rest of this session regardless of whether the write succeeds. When
/// [store] is omitted, changes remain in-memory only.
///
/// Persistence writes are serialized (see [_enqueuePersist]): each begins
/// only after the previous one has settled, so a rapid sequence of spends
/// always finishes persisted as the final balance, never reordered by
/// however long an individual write happens to take.
class CoinWallet extends ChangeNotifier {
  CoinWallet({
    int initialBalance = startingCoinBalance,
    PreferencesStore? store,
  }) : _balance = initialBalance,
       _store = store; // ignore: prefer_initializing_formals

  /// Loads the persisted coin balance from [store].
  ///
  /// A missing or malformed stored value means this wallet has never been
  /// validly initialized — covering both a genuine first-time install and
  /// an existing installation upgrading from an older app version that
  /// never wrote a coin balance at all, since both read `null` from storage
  /// identically. In either case, this seeds the balance to
  /// [startingCoinBalance] and immediately persists that value back to
  /// [store] (via [_persist] — the same path [spend] uses to persist, so
  /// failure handling stays consistent), so a second [load] call reads the
  /// real, now-persisted balance instead of re-initializing every time. A
  /// genuinely stored, valid balance — including `0` — is always restored
  /// verbatim, and this initializing write is never attempted for it.
  ///
  /// If that initializing write fails, the returned wallet still starts
  /// with an in-memory balance of [startingCoinBalance] — never negative or
  /// otherwise invalid — and the failure is recorded on
  /// [debugLastPersistError], exactly like a failed [spend] persistence;
  /// this never throws and never leaves the app unusable.
  ///
  /// A storage *read* failure (as opposed to a missing/malformed value) is
  /// handled more conservatively: since it's impossible to tell whether a
  /// real balance exists behind the failing read, this falls back to an
  /// in-memory [startingCoinBalance] without attempting to write anything,
  /// so a transient read glitch can never overwrite real stored data.
  static Future<CoinWallet> load(PreferencesStore store) async {
    int balance;
    var needsInitializingWrite = false;
    try {
      final stored = await store.getString(StorageKeys.coinBalance);
      if (stored == null) {
        balance = startingCoinBalance;
        needsInitializingWrite = true;
      } else {
        final parsed = int.tryParse(stored);
        if (parsed == null) {
          balance = startingCoinBalance;
          needsInitializingWrite = true;
        } else {
          balance = parsed;
        }
      }
    } on PreferencesStoreException {
      balance = startingCoinBalance;
    }

    final wallet = CoinWallet(initialBalance: balance, store: store);
    if (needsInitializingWrite) {
      await wallet._persist(balance);
    }
    return wallet;
  }

  final PreferencesStore? _store;
  int _balance;
  bool _disposed = false;

  /// The current coin balance. Never negative.
  int get balance => _balance;

  /// The error thrown by the most recent persistence attempt, or `null` if
  /// none has failed. Exposed only so tests can assert a write was actually
  /// attempted and failed, rather than silently skipped; a failed
  /// persistence write is non-fatal — the in-memory balance keeps applying
  /// regardless.
  @visibleForTesting
  Object? get debugLastPersistError => _lastPersistError;
  Object? _lastPersistError;

  /// The tail of the persistence-write queue. See the class-level doc.
  Future<void> _persistTail = Future<void>.value();

  /// Attempts to deduct [amount] coins.
  ///
  /// Returns `true` and updates [balance] immediately — synchronously,
  /// before any `await` — if `balance >= amount`; returns `false` and
  /// leaves [balance] completely unchanged otherwise (insufficient funds,
  /// a non-positive [amount], or this wallet already disposed). Because the
  /// balance check and mutation happen synchronously within this one call,
  /// two calls made back-to-back (e.g. a caller invoking [spend] twice in a
  /// row for what should be a single deduction) can never both succeed
  /// against a balance that only actually covers one of them — the second
  /// call always observes the first call's already-applied deduction.
  /// [balance] can never become negative: a call that would take it below
  /// zero simply fails instead.
  bool spend(int amount) {
    if (_disposed || amount <= 0) return false;
    if (_balance < amount) return false;
    _balance -= amount;
    notifyListeners();
    unawaited(_enqueuePersist(_balance));
    return true;
  }

  Future<void> _enqueuePersist(int balance) {
    final result = _persistTail.then((_) => _persist(balance));
    _persistTail = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<void> _persist(int balance) async {
    final store = _store;
    if (store == null) return;
    try {
      await store.setString(StorageKeys.coinBalance, '$balance');
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
