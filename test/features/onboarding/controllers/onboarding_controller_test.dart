import 'package:cowbullgame/features/onboarding/controllers/onboarding_controller.dart';
import 'package:cowbullgame/features/onboarding/data/onboarding_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeOnboardingRepository implements OnboardingRepository {
  bool? storedValue;
  bool failLoad = false;
  bool failSave = false;
  int saveCallCount = 0;

  @override
  Future<bool?> loadCompleted() async {
    if (failLoad) throw Exception('forced load failure');
    return storedValue;
  }

  @override
  Future<void> saveCompleted(bool completed) async {
    saveCallCount++;
    if (failSave) throw Exception('forced save failure');
    storedValue = completed;
  }

  @override
  Future<void> clear() async => storedValue = null;
}

void main() {
  group('OnboardingController.load', () {
    test('a fresh install (nothing stored) with no existing-install signal '
        'shows onboarding', () async {
      final controller = await OnboardingController.load(
        repository: _FakeOnboardingRepository(),
        treatAsCompletedIfMissing: false,
      );
      expect(controller.completed, isFalse);
    });

    test('a fresh onboarding flag but a genuine existing-install signal is '
        'treated as already completed', () async {
      final controller = await OnboardingController.load(
        repository: _FakeOnboardingRepository(),
        treatAsCompletedIfMissing: true,
      );
      expect(controller.completed, isTrue);
    });

    test('an explicitly stored value is restored verbatim, regardless of '
        'the existing-install signal', () async {
      final repository = _FakeOnboardingRepository()..storedValue = false;
      final controller = await OnboardingController.load(
        repository: repository,
        treatAsCompletedIfMissing: true,
      );
      expect(controller.completed, isFalse);
    });

    test('a repository read failure recovers safely using the '
        'existing-install signal', () async {
      final repository = _FakeOnboardingRepository()..failLoad = true;
      final controller = await OnboardingController.load(
        repository: repository,
        treatAsCompletedIfMissing: true,
      );
      expect(controller.completed, isTrue);
    });
  });

  group('OnboardingController.markCompleted', () {
    test('flips completed to true and notifies listeners', () async {
      final controller = OnboardingController(initialCompleted: false);
      var notified = false;
      controller.addListener(() => notified = true);

      controller.markCompleted();

      expect(controller.completed, isTrue);
      expect(notified, isTrue);
    });

    test('persists the completed flag', () async {
      final repository = _FakeOnboardingRepository();
      final controller = OnboardingController(
        initialCompleted: false,
        repository: repository,
      );

      controller.markCompleted();
      await Future<void>.delayed(Duration.zero);

      expect(repository.storedValue, isTrue);
    });

    test('is a no-op when already completed — no extra notification or '
        'persistence write', () async {
      final repository = _FakeOnboardingRepository()..storedValue = true;
      final controller = OnboardingController(
        initialCompleted: true,
        repository: repository,
      );
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.markCompleted();
      await Future<void>.delayed(Duration.zero);

      expect(notifyCount, 0);
      expect(repository.saveCallCount, 0);
    });

    test('a persistence failure does not revert the in-memory flag and does '
        'not throw', () async {
      final repository = _FakeOnboardingRepository()..failSave = true;
      final controller = OnboardingController(
        initialCompleted: false,
        repository: repository,
      );

      controller.markCompleted();
      await Future<void>.delayed(Duration.zero);

      expect(controller.completed, isTrue);
      expect(controller.debugLastPersistError, isNotNull);
    });

    test('does nothing once disposed', () {
      final controller = OnboardingController(initialCompleted: false);
      controller.dispose();

      expect(controller.markCompleted, returnsNormally);
    });
  });
}
