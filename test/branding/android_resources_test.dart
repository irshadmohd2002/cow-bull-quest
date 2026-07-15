import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads a PNG's (width, height) straight from its IHDR chunk (bytes 16-23:
/// two 4-byte big-endian integers) - no image-decoding package dependency
/// needed just to assert a couple of file dimensions in tests.
(int, int) _pngSize(File file) {
  final bytes = file.readAsBytesSync();
  final width =
      (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
  final height =
      (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
  return (width, height);
}

void main() {
  final res = Directory('android/app/src/main/res');
  const densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];

  group('Android launcher-icon resources', () {
    test('adaptive-icon XML exists with foreground/background/monochrome', () {
      for (final name in ['ic_launcher.xml', 'ic_launcher_round.xml']) {
        final file = File('${res.path}/mipmap-anydpi-v26/$name');
        expect(file.existsSync(), isTrue, reason: '${file.path} is missing');
        final content = file.readAsStringSync();
        expect(content, contains('<foreground'));
        expect(content, contains('<background'));
        expect(content, contains('<monochrome'));
      }
    });

    test('adaptive-icon background is a drawable, not a bundled PNG', () {
      final file = File('${res.path}/drawable/ic_launcher_background.xml');
      expect(file.existsSync(), isTrue);
    });

    for (final density in densities) {
      test('$density has legacy, round, foreground, and monochrome PNGs', () {
        final dir = Directory('${res.path}/mipmap-$density');
        for (final name in [
          'ic_launcher.png',
          'ic_launcher_round.png',
          'ic_launcher_foreground.png',
          'ic_launcher_monochrome.png',
        ]) {
          final file = File('${dir.path}/$name');
          expect(file.existsSync(), isTrue, reason: '${file.path} is missing');
          expect(file.lengthSync(), greaterThan(100));
        }
      });
    }

    test('no default Flutter template icon remains (legacy PNGs were '
        'regenerated, not left at their tiny original template size)', () {
      // The stock Flutter template's mipmap-xxxhdpi/ic_launcher.png is well
      // under 2KB; the real Cow Bull Quest icon resized to that density is
      // meaningfully larger.
      final file = File('${res.path}/mipmap-xxxhdpi/ic_launcher.png');
      expect(file.lengthSync(), greaterThan(2000));
    });
  });

  group('Splash resources', () {
    test('values-v31/styles.xml exists for the Android 12+ splash API', () {
      final file = File('${res.path}/values-v31/styles.xml');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('windowSplashScreenBackground'));
      expect(content, contains('windowSplashScreenAnimatedIcon'));
    });

    test('splash_background color is defined and reused by launch_background '
        'and NormalTheme (no white flash)', () {
      final colors = File('${res.path}/values/colors.xml').readAsStringSync();
      expect(colors, contains('splash_background'));

      for (final path in [
        '${res.path}/drawable/launch_background.xml',
        '${res.path}/drawable-v21/launch_background.xml',
      ]) {
        final content = File(path).readAsStringSync();
        expect(content, contains('@color/splash_background'));
      }

      for (final path in [
        '${res.path}/values/styles.xml',
        '${res.path}/values-night/styles.xml',
      ]) {
        final content = File(path).readAsStringSync();
        expect(content, contains('@color/splash_background'));
      }
    });
  });

  group('App identity in Android configuration', () {
    test('AndroidManifest label is Cow Bull Quest', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('android:label="Cow Bull Quest"'));
      expect(
        manifest,
        contains('android:roundIcon="@mipmap/ic_launcher_round"'),
      );
    });

    test('application ID / namespace remain com.cowbullgame.app', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('namespace = "com.cowbullgame.app"'));
      expect(gradle, contains('applicationId = "com.cowbullgame.app"'));
    });

    test('release signing configuration is unchanged (still gated on '
        'android/key.properties, still no debug-key fallback)', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('key.properties'));
      expect(gradle, contains('GradleException'));
    });
  });

  group('Store and branding assets', () {
    test('approved launcher-icon source exists', () {
      expect(
        File('assets/branding/cow_bull_quest_icon.png').existsSync(),
        isTrue,
      );
    });

    test('store icon exists and is exactly 512x512', () {
      final file = File(
        'docs/play_store/assets/cow_bull_quest_store_icon_512.png',
      );
      expect(file.existsSync(), isTrue);
      expect(_pngSize(file), (512, 512));
    });

    test('UI mockup is not declared as a Flutter runtime asset', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, isNot(contains('cow_bull_quest_ui_mockup')));
      expect(pubspec, isNot(contains('docs/design')));
    });

    test('the branding icon is declared narrowly - the single icon file, '
        'not the whole branding directory', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('assets/branding/cow_bull_quest_icon.png'));
      // Narrow (one file), not a bare directory entry that would bundle
      // everything ever added under assets/branding/.
      expect(pubspec, isNot(contains('- assets/branding/\n')));
    });

    test('no Tricent (or other company) branding anywhere in app '
        'configuration or branding docs', () {
      // branding_guide.md is the one expected exception: it documents "no
      // Tricent branding" as a prohibited-use rule, per Milestone 11 Part
      // 14 - that is a rule statement, not actual Tricent branding.
      final searchRoots = [
        Directory('android'),
        Directory('lib'),
        Directory('docs/play_store'),
      ];
      for (final root in searchRoots) {
        for (final entry in root.listSync(recursive: true)) {
          if (entry is! File) continue;
          final normalizedPath = entry.path.replaceAll('\\', '/');
          if (normalizedPath.endsWith('docs/play_store/branding_guide.md')) {
            continue;
          }
          final name = entry.path.toLowerCase();
          final isTextFile =
              name.endsWith('.xml') ||
              name.endsWith('.kts') ||
              name.endsWith('.dart') ||
              name.endsWith('.md') ||
              name.endsWith('.properties');
          if (!isTextFile) continue;
          final content = entry.readAsStringSync();
          expect(
            content.toLowerCase(),
            isNot(contains('tricent')),
            reason: '${entry.path} must not mention Tricent',
          );
        }
      }
    });
  });
}
