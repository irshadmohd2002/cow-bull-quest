import 'package:cowbullgame/coin_wallet.dart';
import 'package:cowbullgame/core/persistence/storage_keys.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_preferences_store.dart';

void main() {
  group('CoinWallet default', () {
    test('defaults to the starting balance', () {
      final wallet = CoinWallet();
      expect(wallet.balance, startingCoinBalance);
      expect(wallet.balance, 100);
    });
  });

  group('CoinWallet.load', () {
    test(
      'a missing stored balance initializes to the starting balance',
      () async {
        final wallet = await CoinWallet.load(FakePreferencesStore());
        expect(wallet.balance, startingCoinBalance);
      },
    );

    test('an existing installation upgrading with no coin-balance key also '
        'initializes to the starting balance — indistinguishable from a '
        'first-time install', () async {
      // Simulates an upgrade: other keys exist (as an old version would
      // have written), but never the coin-balance key.
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.themePreference: 'dark'},
      );
      final wallet = await CoinWallet.load(store);
      expect(wallet.balance, startingCoinBalance);
    });

    test('an existing stored balance is preserved verbatim', () async {
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.coinBalance: '42'},
      );
      final wallet = await CoinWallet.load(store);
      expect(wallet.balance, 42);
    });

    test('a stored balance of zero is preserved, not reset to the starting '
        'balance', () async {
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.coinBalance: '0'},
      );
      final wallet = await CoinWallet.load(store);
      expect(wallet.balance, 0);
    });

    test('an existing stored balance, including zero, is never overwritten '
        'by an initializing write', () async {
      final zeroStore = FakePreferencesStore(
        initialValues: {StorageKeys.coinBalance: '0'},
      );
      await CoinWallet.load(zeroStore);
      expect(zeroStore.setStringCalls, isEmpty);
      expect(zeroStore.values[StorageKeys.coinBalance], '0');

      final nonZeroStore = FakePreferencesStore(
        initialValues: {StorageKeys.coinBalance: '42'},
      );
      await CoinWallet.load(nonZeroStore);
      expect(nonZeroStore.setStringCalls, isEmpty);
      expect(nonZeroStore.values[StorageKeys.coinBalance], '42');
    });

    test('a storage read failure is handled safely, falling back to the '
        'starting balance', () async {
      final store = FakePreferencesStore()..failGetString = true;
      final wallet = await CoinWallet.load(store);
      expect(wallet.balance, startingCoinBalance);
    });

    test('a storage read failure does not attempt to write anything — a '
        'transient read glitch can never overwrite real stored data', () async {
      final store = FakePreferencesStore()..failGetString = true;
      await CoinWallet.load(store);
      expect(store.setStringCalls, isEmpty);
    });

    group('an absent key', () {
      test('writes the starting balance to storage exactly once', () async {
        final store = FakePreferencesStore();

        await CoinWallet.load(store);

        expect(
          store.setStringCalls.where((key) => key == StorageKeys.coinBalance),
          hasLength(1),
        );
        expect(store.values[StorageKeys.coinBalance], '100');
      });

      test('a second load reads the now-persisted balance and does not '
          'initialize or write again', () async {
        final store = FakePreferencesStore();

        final first = await CoinWallet.load(store);
        expect(first.balance, startingCoinBalance);
        expect(store.setStringCalls, hasLength(1));

        final second = await CoinWallet.load(store);
        expect(second.balance, startingCoinBalance);
        // No additional write: the second load found a real, already-
        // persisted value and never treated the wallet as newly created.
        expect(store.setStringCalls, hasLength(1));
      });
    });

    group('a malformed stored value', () {
      test('recovers to the starting balance rather than throwing', () async {
        final store = FakePreferencesStore(
          initialValues: {StorageKeys.coinBalance: 'not-a-number'},
        );
        final wallet = await CoinWallet.load(store);
        expect(wallet.balance, startingCoinBalance);
      });

      test('persists the repaired starting balance back to storage', () async {
        final store = FakePreferencesStore(
          initialValues: {StorageKeys.coinBalance: 'not-a-number'},
        );

        await CoinWallet.load(store);

        expect(store.values[StorageKeys.coinBalance], '100');
      });

      test('a later load then reads the repaired value without treating it '
          'as malformed again', () async {
        final store = FakePreferencesStore(
          initialValues: {StorageKeys.coinBalance: 'not-a-number'},
        );

        await CoinWallet.load(store);
        final second = await CoinWallet.load(store);

        expect(second.balance, startingCoinBalance);
        expect(store.setStringCalls, hasLength(1));
      });
    });

    group('an initializing write failure', () {
      test('does not throw and leaves an in-memory balance of 100', () async {
        final store = FakePreferencesStore()..failSetString = true;

        final wallet = await CoinWallet.load(store);

        expect(wallet.balance, startingCoinBalance);
      });

      test('never produces a negative or otherwise invalid balance', () async {
        final store = FakePreferencesStore()..failSetString = true;

        final wallet = await CoinWallet.load(store);

        expect(wallet.balance, greaterThanOrEqualTo(0));
        expect(wallet.balance, 100);
      });

      test('records the failure the same way a failed spend does', () async {
        final store = FakePreferencesStore()..failSetString = true;

        final wallet = await CoinWallet.load(store);

        expect(wallet.debugLastPersistError, isNotNull);
      });

      test('the app stays usable — a subsequent successful spend still '
          'works and clears the recorded error', () async {
        final store = FakePreferencesStore()..failSetString = true;
        final wallet = await CoinWallet.load(store);
        expect(wallet.debugLastPersistError, isNotNull);

        store.failSetString = false;
        final spent = wallet.spend(20);
        await Future<void>.delayed(Duration.zero);

        expect(spent, isTrue);
        expect(wallet.balance, 80);
        expect(wallet.debugLastPersistError, isNull);
      });
    });

    test('restarting the app (a second load) does not reset an existing '
        'balance back to the starting balance', () async {
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.coinBalance: '35'},
      );
      final first = await CoinWallet.load(store);
      expect(first.balance, 35);

      final second = await CoinWallet.load(store);
      expect(second.balance, 35);
    });
  });

  group('CoinWallet.spend', () {
    test('deducting 20 from a sufficient balance succeeds', () {
      final wallet = CoinWallet(initialBalance: 100);
      final result = wallet.spend(20);
      expect(result, isTrue);
      expect(wallet.balance, 80);
    });

    test('insufficient funds does not deduct anything', () {
      final wallet = CoinWallet(initialBalance: 10);
      final result = wallet.spend(20);
      expect(result, isFalse);
      expect(wallet.balance, 10);
    });

    test('spending exactly the full balance succeeds and leaves zero', () {
      final wallet = CoinWallet(initialBalance: 20);
      expect(wallet.spend(20), isTrue);
      expect(wallet.balance, 0);
    });

    test('the balance can never become negative — repeated spends beyond '
        'the balance all fail once it is exhausted', () {
      final wallet = CoinWallet(initialBalance: 25);
      expect(wallet.spend(20), isTrue);
      expect(wallet.balance, 5);
      expect(wallet.spend(20), isFalse);
      expect(wallet.balance, 5);
      expect(wallet.balance, greaterThanOrEqualTo(0));
    });

    test('a non-positive amount is rejected without deducting', () {
      final wallet = CoinWallet(initialBalance: 100);
      expect(wallet.spend(0), isFalse);
      expect(wallet.spend(-5), isFalse);
      expect(wallet.balance, 100);
    });

    test('two calls back-to-back cannot both spend against a balance that '
        'only covers one of them', () {
      final wallet = CoinWallet(initialBalance: 20);
      final first = wallet.spend(20);
      final second = wallet.spend(20);
      expect(first, isTrue);
      expect(second, isFalse);
      expect(wallet.balance, 0);
    });

    test('updates the balance immediately, before any persistence write '
        'completes', () {
      final store = FakePreferencesStore();
      final wallet = CoinWallet(initialBalance: 100, store: store);
      wallet.spend(20);
      expect(wallet.balance, 80);
    });

    test('notifies listeners on a successful spend', () {
      final wallet = CoinWallet(initialBalance: 100);
      var notifyCount = 0;
      wallet.addListener(() => notifyCount++);
      wallet.spend(20);
      expect(notifyCount, 1);
    });

    test('does not notify listeners on a failed spend', () {
      final wallet = CoinWallet(initialBalance: 10);
      var notifyCount = 0;
      wallet.addListener(() => notifyCount++);
      wallet.spend(20);
      expect(notifyCount, 0);
    });
  });

  group('CoinWallet persistence', () {
    test('a successful spend persists the new balance', () async {
      final store = FakePreferencesStore();
      final wallet = CoinWallet(initialBalance: 100, store: store);

      wallet.spend(20);
      await Future<void>.delayed(Duration.zero);

      expect(store.values[StorageKeys.coinBalance], '80');
    });

    test('persistence succeeds across reloads — a spent balance survives a '
        'fresh CoinWallet.load', () async {
      final store = FakePreferencesStore();
      final wallet = CoinWallet(initialBalance: 100, store: store);
      wallet.spend(20);
      await Future<void>.delayed(Duration.zero);

      final reloaded = await CoinWallet.load(store);
      expect(reloaded.balance, 80);
    });

    test(
      'a persistence failure does not revert the in-memory deduction',
      () async {
        final store = FakePreferencesStore()..failSetString = true;
        final wallet = CoinWallet(initialBalance: 100, store: store);

        wallet.spend(20);
        await Future<void>.delayed(Duration.zero);

        expect(wallet.balance, 80);
        expect(wallet.debugLastPersistError, isNotNull);
      },
    );

    test('without a store, spends remain in-memory only', () async {
      final wallet = CoinWallet(initialBalance: 100);
      wallet.spend(20);
      await Future<void>.delayed(Duration.zero);
      expect(wallet.balance, 80);
    });

    test('a rapid sequence of spends persists the final balance, never '
        'reordered by write speed', () async {
      final store = FakePreferencesStore()
        ..setStringDelays['80'] = const Duration(milliseconds: 30);
      final wallet = CoinWallet(initialBalance: 100, store: store);

      wallet.spend(20);
      wallet.spend(20);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(wallet.balance, 60);
      expect(store.values[StorageKeys.coinBalance], '60');
    });
  });

  group('CoinWallet disposal', () {
    test('disposing does not throw', () {
      final wallet = CoinWallet();
      expect(wallet.dispose, returnsNormally);
    });

    test('spending after disposal fails and does not throw or notify', () {
      final wallet = CoinWallet(initialBalance: 100);
      var notifyCount = 0;
      wallet.addListener(() => notifyCount++);
      wallet.dispose();

      expect(wallet.spend(20), isFalse);
      expect(notifyCount, 0);
    });

    test('earning after disposal fails and does not throw or notify', () {
      final wallet = CoinWallet(initialBalance: 100);
      var notifyCount = 0;
      wallet.addListener(() => notifyCount++);
      wallet.dispose();

      expect(wallet.earn(15), isFalse);
      expect(notifyCount, 0);
    });
  });

  group('Milestone 19: CoinWallet.earn', () {
    test('granting a positive amount succeeds and increases the balance', () {
      final wallet = CoinWallet(initialBalance: 100);
      final result = wallet.earn(15);
      expect(result, isTrue);
      expect(wallet.balance, 115);
    });

    test('has no upper bound — a large amount still succeeds', () {
      final wallet = CoinWallet(initialBalance: 100);
      expect(wallet.earn(1000000), isTrue);
      expect(wallet.balance, 1000100);
    });

    test('a non-positive amount is rejected without granting anything', () {
      final wallet = CoinWallet(initialBalance: 100);
      expect(wallet.earn(0), isFalse);
      expect(wallet.earn(-5), isFalse);
      expect(wallet.balance, 100);
    });

    test('notifies listeners on a successful earn', () {
      final wallet = CoinWallet(initialBalance: 100);
      var notifyCount = 0;
      wallet.addListener(() => notifyCount++);
      wallet.earn(15);
      expect(notifyCount, 1);
    });

    test('does not notify listeners on a rejected earn', () {
      final wallet = CoinWallet(initialBalance: 100);
      var notifyCount = 0;
      wallet.addListener(() => notifyCount++);
      wallet.earn(0);
      expect(notifyCount, 0);
    });

    test('updates the balance immediately, before any persistence write '
        'completes', () {
      final store = FakePreferencesStore();
      final wallet = CoinWallet(initialBalance: 100, store: store);
      wallet.earn(15);
      expect(wallet.balance, 115);
    });

    test('a successful earn persists the new balance', () async {
      final store = FakePreferencesStore();
      final wallet = CoinWallet(initialBalance: 100, store: store);

      wallet.earn(15);
      await Future<void>.delayed(Duration.zero);

      expect(store.values[StorageKeys.coinBalance], '115');
    });

    test('a persistence failure does not revert the in-memory grant', () async {
      final store = FakePreferencesStore()..failSetString = true;
      final wallet = CoinWallet(initialBalance: 100, store: store);

      wallet.earn(15);
      await Future<void>.delayed(Duration.zero);

      expect(wallet.balance, 115);
      expect(wallet.debugLastPersistError, isNotNull);
    });

    test('without a store, earns remain in-memory only', () async {
      final wallet = CoinWallet(initialBalance: 100);
      wallet.earn(15);
      await Future<void>.delayed(Duration.zero);
      expect(wallet.balance, 115);
    });
  });

  group('Milestone 19: CoinWallet lifetime totals', () {
    test('a fresh wallet starts with zero earned and zero spent', () {
      final wallet = CoinWallet();
      expect(wallet.totalCoinsEarned, 0);
      expect(wallet.totalCoinsSpent, 0);
    });

    test('earn increases totalCoinsEarned but never totalCoinsSpent', () {
      final wallet = CoinWallet(initialBalance: 100);
      wallet.earn(15);
      wallet.earn(10);
      expect(wallet.totalCoinsEarned, 25);
      expect(wallet.totalCoinsSpent, 0);
    });

    test('spend increases totalCoinsSpent but never totalCoinsEarned', () {
      final wallet = CoinWallet(initialBalance: 100);
      wallet.spend(20);
      wallet.spend(20);
      expect(wallet.totalCoinsSpent, 40);
      expect(wallet.totalCoinsEarned, 0);
    });

    test('a failed spend (insufficient funds) never increases '
        'totalCoinsSpent', () {
      final wallet = CoinWallet(initialBalance: 10);
      wallet.spend(20);
      expect(wallet.totalCoinsSpent, 0);
    });

    test('totals persist across a reload', () async {
      final store = FakePreferencesStore();
      final wallet = CoinWallet(initialBalance: 100, store: store);
      wallet.earn(15);
      wallet.spend(20);
      await Future<void>.delayed(Duration.zero);

      final reloaded = await CoinWallet.load(store);
      expect(reloaded.balance, 95);
      expect(reloaded.totalCoinsEarned, 15);
      expect(reloaded.totalCoinsSpent, 20);
    });

    test('spending coins never reduces totalCoinsEarned, and earning more '
        'never reduces totalCoinsSpent — the two totals are independent of '
        'the current balance and of each other', () {
      final wallet = CoinWallet(initialBalance: 100);
      wallet.earn(50);
      wallet.spend(30);
      wallet.earn(10);
      expect(wallet.balance, 130);
      expect(wallet.totalCoinsEarned, 60);
      expect(wallet.totalCoinsSpent, 30);
    });
  });

  group('Milestone 19: CoinWallet.load totals migration', () {
    test('an installation that predates Milestone 19 (balance present, no '
        'totals keys at all) reads both totals as 0', () async {
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.coinBalance: '42'},
      );
      final wallet = await CoinWallet.load(store);
      expect(wallet.balance, 42);
      expect(wallet.totalCoinsEarned, 0);
      expect(wallet.totalCoinsSpent, 0);
    });

    test('a genuinely stored total of 0 is preserved, not confused with a '
        'missing key', () async {
      final store = FakePreferencesStore(
        initialValues: {
          StorageKeys.coinBalance: '100',
          StorageKeys.totalCoinsEarned: '0',
          StorageKeys.totalCoinsSpent: '0',
        },
      );
      final wallet = await CoinWallet.load(store);
      expect(wallet.totalCoinsEarned, 0);
      expect(wallet.totalCoinsSpent, 0);
    });

    test('existing, valid stored totals are restored verbatim', () async {
      final store = FakePreferencesStore(
        initialValues: {
          StorageKeys.coinBalance: '100',
          StorageKeys.totalCoinsEarned: '250',
          StorageKeys.totalCoinsSpent: '120',
        },
      );
      final wallet = await CoinWallet.load(store);
      expect(wallet.totalCoinsEarned, 250);
      expect(wallet.totalCoinsSpent, 120);
    });

    test(
      'a malformed stored total recovers to 0 rather than throwing',
      () async {
        final store = FakePreferencesStore(
          initialValues: {
            StorageKeys.coinBalance: '100',
            StorageKeys.totalCoinsEarned: 'not-a-number',
            StorageKeys.totalCoinsSpent: 'also-not-a-number',
          },
        );
        final wallet = await CoinWallet.load(store);
        expect(wallet.totalCoinsEarned, 0);
        expect(wallet.totalCoinsSpent, 0);
      },
    );

    test('a negative stored total recovers to 0 rather than being trusted '
        'verbatim', () async {
      final store = FakePreferencesStore(
        initialValues: {
          StorageKeys.coinBalance: '100',
          StorageKeys.totalCoinsEarned: '-5',
          StorageKeys.totalCoinsSpent: '-1',
        },
      );
      final wallet = await CoinWallet.load(store);
      expect(wallet.totalCoinsEarned, 0);
      expect(wallet.totalCoinsSpent, 0);
    });

    test(
      'a totals read failure is handled safely, falling back to 0',
      () async {
        final store = FakePreferencesStore(
          initialValues: {StorageKeys.coinBalance: '100'},
        )..failGetString = true;
        final wallet = await CoinWallet.load(store);
        // The balance read also fails under this same forced failure, so this
        // exercises both fallbacks together — balance to startingCoinBalance,
        // totals to 0 — rather than needing a call-count-aware fake.
        expect(wallet.balance, startingCoinBalance);
        expect(wallet.totalCoinsEarned, 0);
        expect(wallet.totalCoinsSpent, 0);
      },
    );

    test('reading totals never triggers an initializing write the way a '
        'missing balance does', () async {
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.coinBalance: '42'},
      );
      await CoinWallet.load(store);
      expect(
        store.setStringCalls.where(
          (key) => key == StorageKeys.totalCoinsEarned,
        ),
        isEmpty,
      );
      expect(
        store.setStringCalls.where((key) => key == StorageKeys.totalCoinsSpent),
        isEmpty,
      );
    });
  });

  group('Milestone 19: CoinWallet.earn onPersisted', () {
    test(
      'fires exactly once, asynchronously, after a successful write',
      () async {
        final store = FakePreferencesStore();
        final wallet = CoinWallet(initialBalance: 100, store: store);
        var callCount = 0;

        wallet.earn(15, onPersisted: () => callCount++);
        // Not yet called synchronously — it only fires once the write settles.
        expect(callCount, 0);

        await Future<void>.delayed(Duration.zero);

        expect(callCount, 1);
      },
    );

    test('never fires when the persistence write fails', () async {
      final store = FakePreferencesStore()..failSetString = true;
      final wallet = CoinWallet(initialBalance: 100, store: store);
      var callCount = 0;

      wallet.earn(15, onPersisted: () => callCount++);
      await Future<void>.delayed(Duration.zero);

      expect(callCount, 0);
      expect(wallet.debugLastPersistError, isNotNull);
      // The in-memory grant still applies regardless of the write failing.
      expect(wallet.balance, 115);
    });

    test('fires even without a store — nothing to persist is treated as '
        'trivially successful, not a failure', () async {
      final wallet = CoinWallet(initialBalance: 100);
      var callCount = 0;

      wallet.earn(15, onPersisted: () => callCount++);
      await Future<void>.delayed(Duration.zero);

      expect(callCount, 1);
    });

    test('never fires for a rejected grant (non-positive amount)', () async {
      final store = FakePreferencesStore();
      final wallet = CoinWallet(initialBalance: 100, store: store);
      var callCount = 0;

      wallet.earn(0, onPersisted: () => callCount++);
      wallet.earn(-5, onPersisted: () => callCount++);
      await Future<void>.delayed(Duration.zero);

      expect(callCount, 0);
    });

    test('never fires once the wallet is disposed, even if the write was '
        'already in flight', () async {
      final store = FakePreferencesStore();
      final wallet = CoinWallet(initialBalance: 100, store: store);
      var callCount = 0;

      wallet.earn(15, onPersisted: () => callCount++);
      wallet.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(callCount, 0);
    });

    test(
      'omitting onPersisted is safe — earn behaves exactly as before',
      () async {
        final store = FakePreferencesStore();
        final wallet = CoinWallet(initialBalance: 100, store: store);

        final result = wallet.earn(15);
        await Future<void>.delayed(Duration.zero);

        expect(result, isTrue);
        expect(wallet.balance, 115);
      },
    );
  });

  group('Milestone 19: CoinWallet partial-write failure and self-healing', () {
    test('a failure limited to one key (totalCoinsEarned) still lets the '
        'other keys in the same call persist first, and reports failure '
        'overall', () async {
      final store = FakePreferencesStore()
        ..failSetStringForKeys.add(StorageKeys.totalCoinsEarned);
      final wallet = CoinWallet(initialBalance: 100, store: store);

      wallet.earn(15);
      await Future<void>.delayed(Duration.zero);

      // coinBalance is written before totalCoinsEarned in wallet's own
      // write order, so it succeeds even though the call overall failed.
      expect(store.values[StorageKeys.coinBalance], '115');
      expect(store.values.containsKey(StorageKeys.totalCoinsEarned), isFalse);
      expect(wallet.debugLastPersistError, isNotNull);
    });

    test('the next successful earn/spend re-sends every field, healing the '
        'previously-failed key', () async {
      final store = FakePreferencesStore()
        ..failSetStringForKeys.add(StorageKeys.totalCoinsEarned);
      final wallet = CoinWallet(initialBalance: 100, store: store);

      wallet.earn(15);
      await Future<void>.delayed(Duration.zero);
      expect(store.values.containsKey(StorageKeys.totalCoinsEarned), isFalse);

      store.failSetStringForKeys.clear();
      wallet.spend(5);
      await Future<void>.delayed(Duration.zero);

      // The healing write carries the *current* in-memory totalCoinsEarned
      // (15, from the earlier grant that only failed to persist, not to
      // apply), not a stale or zeroed value.
      expect(store.values[StorageKeys.totalCoinsEarned], '15');
      expect(store.values[StorageKeys.coinBalance], '110');
      expect(store.values[StorageKeys.totalCoinsSpent], '5');
      expect(wallet.debugLastPersistError, isNull);
    });

    test('in-memory balance and totals are unaffected by a partial write '
        'failure either way', () async {
      final store = FakePreferencesStore()
        ..failSetStringForKeys.add(StorageKeys.totalCoinsSpent);
      final wallet = CoinWallet(initialBalance: 100, store: store);

      wallet.spend(20);
      await Future<void>.delayed(Duration.zero);

      expect(wallet.balance, 80);
      expect(wallet.totalCoinsSpent, 20);
    });
  });
}
