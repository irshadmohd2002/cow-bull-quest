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
  });
}
