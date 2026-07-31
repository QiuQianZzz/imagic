import 'package:flutter_test/flutter_test.dart';

import 'package:imagic/core/utils/version.dart';

void main() {
  group('Version.parse', () {
    test('basic semver', () {
      final v = Version.parse('0.1.0');
      expect(v.major, 0);
      expect(v.minor, 1);
      expect(v.patch, 0);
      expect(v.prerelease, isNull);
      expect(v.isPrerelease, isFalse);
    });

    test('v prefix stripped', () {
      final v = Version.parse('v0.1.0-beta.2');
      expect(v.major, 0);
      expect(v.prerelease, 'beta.2');
      expect(v.isPrerelease, isTrue);
    });

    test('build metadata', () {
      final v = Version.parse('0.1.0+1');
      expect(v.buildMetadata, '1');
      expect(v.prerelease, isNull);
    });

    test('prerelease with build metadata', () {
      final v = Version.parse('v0.1.0-beta.2+1');
      expect(v.prerelease, 'beta.2');
      expect(v.buildMetadata, '1');
    });

    test('missing segments default to zero', () {
      final v = Version.parse('1.2');
      expect(v.major, 1);
      expect(v.minor, 2);
      expect(v.patch, 0);
    });
  });

  group('Version compareTo', () {
    test('equal versions', () {
      expect(Version.parse('0.1.0') == Version.parse('0.1.0'), isTrue);
      expect(Version.parse('0.1.0') < Version.parse('0.1.0'), isFalse);
    });

    test('numeric segments', () {
      expect(Version.parse('0.1.1') > Version.parse('0.1.0'), isTrue);
      expect(Version.parse('1.0.0') > Version.parse('0.9.9'), isTrue);
      expect(Version.parse('0.2.0') > Version.parse('0.10.0'), isFalse);
    });

    test('stable beats prerelease with same core', () {
      expect(Version.parse('0.1.0') > Version.parse('0.1.0-beta.2'), isTrue);
      expect(Version.parse('0.1.0-beta.2') < Version.parse('0.1.0'), isTrue);
    });

    test('prerelease ordering', () {
      expect(Version.parse('0.1.0-beta.2') > Version.parse('0.1.0-beta.1'), isTrue);
      expect(Version.parse('0.1.0-beta.10') > Version.parse('0.1.0-beta.9'), isTrue);
      expect(Version.parse('0.1.0-alpha') < Version.parse('0.1.0-beta'), isTrue);
      expect(Version.parse('0.1.0-rc.1') > Version.parse('0.1.0-beta.2'), isTrue);
    });

    test('build metadata ignored in comparison', () {
      expect(Version.parse('0.1.0+1') == Version.parse('0.1.0+2'), isTrue);
      expect(Version.parse('0.1.0+99') >= Version.parse('0.1.0+1'), isTrue);
    });
  });

  test('toString without v prefix', () {
    expect(Version.parse('v0.1.0-beta.2+1').toString(), '0.1.0-beta.2');
    expect(Version.parse('v0.1.0').toString(), '0.1.0');
  });
}
