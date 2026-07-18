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
/// balance ever decreases; [earn] (added in Milestone 19, for completed-game
/// coin rewards — see `features/game/services/coin_reward_calculator.dart`)
/// is the only way it ever increases beyond its starting value. Both are
/// separately tallied for the wallet's lifetime as [totalCoinsEarned] and
/// [totalCoinsSpent], independent of the current [balance] — spending coins
/// never reduces [totalCoinsEarned], and earning more never reduces
/// [totalCoinsSpent].
///
/// If a [PreferencesStore] is supplied, every successful [spend] or [earn]
/// is persisted to it (balance under [StorageKeys.coinBalance],
/// [totalCoinsEarned] and [totalCoinsSpent] under their own
/// [StorageKeys.totalCoinsEarned]/[StorageKeys.totalCoinsSpent] keys) after
/// updating in-memory state and notifying listeners; a persistence failure
/// never reverts the already-applied in-memory change — coins already
/// spent/earned stay applied for the rest of this session regardless of
/// whether the write succeeds. When [store] is omitted, changes remain
/// in-memory only.
///
/// Persistence writes are serialized (see [_enqueuePersist]): each begins
/// only after the previous one has settled, so a rapid sequence of
/// spends/earns always finishes persisted as the final state, never
/// reordered by however long an individual write happens to take.
class CoinWallet extends ChangeNotifier {
  CoinWallet({
    int initialBalance = startingCoinBalance,
    PreferencesStore? store,
    int initialTotalCoinsEarned = 0,
    int initialTotalCoinsSpent = 0,
  }) : _balance = initialBalance,
       _store = store, // ignore: prefer_initializing_formals
       _totalCoinsEarned = initialTotalCoinsEarned,
       _totalCoinsSpent = initialTotalCoinsSpent;

  /// Loads the persisted coin balance and lifetime earned/spent totals from
  /// [store].
  ///
  /// A missing or malformed stored balance means this wallet has never been
  /// validly initialized — covering both a genuine first-time install and
  /// an existing installation upgrading from an older app version that
  /// never wrote a coin balance at all, since both read `null` from storage
  /// identically. In either case, this seeds the balance to
  /// [startingCoinBalance] and immediately persists *only* that value back
  /// to [store] (via [_persistBalanceOnly] — deliberately not the full
  /// [_persist] that [spend]/[earn] use, since [totalCoinsEarned]/
  /// [totalCoinsSpent] have no equivalent "never initialized" ambiguity to
  /// resolve — see their own doc below), so a second [load] call reads the
  /// real, now-persisted balance instead of re-initializing every time.
  /// A genuinely stored, valid balance — including `0` — is always restored
  /// verbatim, and this initializing write is never attempted for it.
  ///
  /// If that initializing write fails, the returned wallet still starts
  /// with an in-memory balance of [startingCoinBalance] — never negative or
  /// otherwise invalid — and the failure is recorded on
  /// [debugLastPersistError], exactly like a failed [spend]/[earn]
  /// persistence; this never throws and never leaves the app unusable.
  ///
  /// A storage *read* failure (as opposed to a missing/malformed value) is
  /// handled more conservatively: since it's impossible to tell whether a
  /// real balance exists behind the failing read, this falls back to an
  /// in-memory [startingCoinBalance] without attempting to write anything,
  /// so a transient read glitch can never overwrite real stored data.
  ///
  /// [totalCoinsEarned] and [totalCoinsSpent] are read independently of
  /// [balance] and never gate an initializing write of their own: a missing,
  /// malformed, or negative stored value simply reads as `0` — indistinguishable
  /// from (and just as correct for) an installation that predates Milestone
  /// 19's coin-reward tracking as it is for a wallet that has genuinely never
  /// earned or spent anything yet. No migration step is required for either
  /// counter beyond this default.
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

    final totalCoinsEarned = await _readNonNegativeCounter(
      store,
      StorageKeys.totalCoinsEarned,
    );
    final totalCoinsSpent = await _readNonNegativeCounter(
      store,
      StorageKeys.totalCoinsSpent,
    );

    final wallet = CoinWallet(
      initialBalance: balance,
      store: store,
      initialTotalCoinsEarned: totalCoinsEarned,
      initialTotalCoinsSpent: totalCoinsSpent,
    );
    if (needsInitializingWrite) {
      await wallet._persistBalanceOnly(balance);
    }
    return wallet;
  }

  /// Reads [key] as a non-negative counter, defaulting to `0` for anything
  /// that isn't a valid, non-negative integer — missing, malformed, negative,
  /// or a failed read alike. See [load]'s doc for why this default never
  /// needs an initializing write the way [balance]'s does.
  static Future<int> _readNonNegativeCounter(
    PreferencesStore store,
    String key,
  ) async {
    try {
      final stored = await store.getString(key);
      if (stored == null) return 0;
      final parsed = int.tryParse(stored);
      if (parsed == null || parsed < 0) return 0;
      return parsed;
    } on PreferencesStoreException {
      return 0;
    }
  }

  final PreferencesStore? _store;
  int _balance;
  int _totalCoinsEarned;
  int _totalCoinsSpent;
  bool _disposed = false;

  /// The current coin balance. Never negative.
  int get balance => _balance;

  /// The lifetime total of every coin ever successfully [earn]ed by this
  /// wallet, independent of [balance] (i.e. never reduced by [spend]).
  /// `0` for a wallet that has never earned a coin reward, including on an
  /// installation that predates Milestone 19 — see [load]'s doc.
  int get totalCoinsEarned => _totalCoinsEarned;

  /// The lifetime total of every coin ever successfully [spend]. Independent
  /// of [balance] (i.e. never reduced by [earn]). `0` for a wallet that has
  /// never spent a coin, including on an installation that predates
  /// Milestone 19 — see [load]'s doc.
  int get totalCoinsSpent => _totalCoinsSpent;

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
  /// leaves [balance] (and [totalCoinsSpent]) completely unchanged otherwise
  /// (insufficient funds, a non-positive [amount], or this wallet already
  /// disposed). Because the balance check and mutation happen synchronously
  /// within this one call, two calls made back-to-back (e.g. a caller
  /// invoking [spend] twice in a row for what should be a single deduction)
  /// can never both succeed against a balance that only actually covers one
  /// of them — the second call always observes the first call's
  /// already-applied deduction. [balance] can never become negative: a call
  /// that would take it below zero simply fails instead.
  bool spend(int amount) {
    if (_disposed || amount <= 0) return false;
    if (_balance < amount) return false;
    _balance -= amount;
    _totalCoinsSpent += amount;
    notifyListeners();
    unawaited(_enqueuePersist());
    return true;
  }

  /// Grants [amount] coins earned as a completed-game reward (see
  /// `CoinRewardCalculator`).
  ///
  /// Returns `true` and updates [balance] and [totalCoinsEarned] immediately
  /// — synchronously, before any `await` — for a positive [amount]; returns
  /// `false` and leaves both completely unchanged for a non-positive
  /// [amount] or once this wallet is disposed. Unlike [spend], there is no
  /// upper bound to check: an [earn] call can never fail for insufficient
  /// funds. This method itself grants exactly what it is asked to grant
  /// exactly once per call — it is the caller's responsibility (the
  /// app-level composition root, driven by `GameController`'s "exactly once
  /// per completed game" contract) to call it exactly once per rewarded
  /// game, never on a restart, an abandoned game, or a widget rebuild.
  ///
  /// [onPersisted], if given, is called at most once, asynchronously, after
  /// this specific grant's write to [store] actually completes — but only
  /// if that write succeeds (or there is no [store] to write to at all,
  /// which is treated as trivially successful, not a failure). It is never
  /// called for a rejected grant (this method already returned `false`), and
  /// never called if the write throws. This exists so a caller can gate
  /// something like a reward sound/haptic on "durably saved", rather than
  /// merely "applied in memory" — see `AudioFeedbackCoordinator.onCoinsEarned`
  /// and `CowBullApp._awardCoinReward`, its only caller.
  bool earn(int amount, {VoidCallback? onPersisted}) {
    if (_disposed || amount <= 0) return false;
    _balance += amount;
    _totalCoinsEarned += amount;
    notifyListeners();
    unawaited(
      _enqueuePersist().then((succeeded) {
        if (succeeded && !_disposed) onPersisted?.call();
      }),
    );
    return true;
  }

  Future<bool> _enqueuePersist() {
    final balance = _balance;
    final totalCoinsEarned = _totalCoinsEarned;
    final totalCoinsSpent = _totalCoinsSpent;
    final result = _persistTail.then(
      (_) => _persist(balance, totalCoinsEarned, totalCoinsSpent),
    );
    _persistTail = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// Writes [balance]/[totalCoinsEarned]/[totalCoinsSpent] and returns
  /// whether the write succeeded. Returns `true` when [store] is `null`
  /// (nothing to fail) or every write completed; returns `false` — and
  /// records the failure on [debugLastPersistError] — the moment any one of
  /// the three throws, at which point any remaining key in this call is left
  /// unwritten. This can leave the *stored* balance/totals briefly
  /// inconsistent with each other (e.g. a new balance durably saved while a
  /// new total is not), but never durably wrong: every field this call
  /// writes is captured fresh from current in-memory state, so the very next
  /// successful [spend]/[earn] call's write re-sends every field's
  /// then-current value, self-healing whatever a prior partial failure left
  /// stale. In-memory state itself is never affected by this outcome either
  /// way — see the class-level doc.
  Future<bool> _persist(
    int balance,
    int totalCoinsEarned,
    int totalCoinsSpent,
  ) async {
    final store = _store;
    if (store == null) return true;
    try {
      await store.setString(StorageKeys.coinBalance, '$balance');
      await store.setString(StorageKeys.totalCoinsEarned, '$totalCoinsEarned');
      await store.setString(StorageKeys.totalCoinsSpent, '$totalCoinsSpent');
      _lastPersistError = null;
      return true;
    } catch (error) {
      _lastPersistError = error;
      return false;
    }
  }

  /// Writes only [StorageKeys.coinBalance], used solely by [load]'s
  /// initializing write — see its doc for why the totals are deliberately
  /// left untouched here rather than also written as `0`.
  Future<void> _persistBalanceOnly(int balance) async {
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
