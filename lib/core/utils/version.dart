/// 语义化版本（SemVer 2.0.0）模型，用于比较不同 tag 的版本高低。
///
/// 仅用于比较，不校验完整合法性：解析时宽松容错（缺省补 0、忽略多余段），
/// 若数字段不可解析会抛出 [FormatException]，由调用方决定如何处理。
class Version implements Comparable<Version> {
  final int major;
  final int minor;
  final int patch;

  /// 预发布标识，如 `beta.2`；正式版为 `null`。
  final String? prerelease;

  /// 构建元数据，如 `1`；无则为 `null`。不参与优先级比较。
  final String? buildMetadata;

  const Version({
    required this.major,
    required this.minor,
    required this.patch,
    this.prerelease,
    this.buildMetadata,
  });

  /// 解析版本字符串，如 `0.1.0`、`v0.1.0-beta.2`、`0.1.0+1`。
  /// 容忍开头 `v`/`V` 前缀。
  factory Version.parse(String raw) {
    var input = raw.trim();
    if (input.isNotEmpty && (input.startsWith('v') || input.startsWith('V'))) {
      input = input.substring(1);
    }
    String? build;
    final plus = input.indexOf('+');
    if (plus >= 0) {
      build = input.substring(plus + 1);
      input = input.substring(0, plus);
    }
    String? pre;
    final minus = input.indexOf('-');
    if (minus >= 0) {
      pre = input.substring(minus + 1);
      input = input.substring(0, minus);
    }
    final parts = input.split('.');
    int at(int i) =>
        parts.length > i && parts[i].isNotEmpty ? int.parse(parts[i]) : 0;
    return Version(
      major: at(0),
      minor: at(1),
      patch: at(2),
      prerelease: pre,
      buildMetadata: build,
    );
  }

  /// 是否为预发行版本（带 beta/rc/alpha 等后缀）。
  bool get isPrerelease => prerelease != null;

  @override
  int compareTo(Version other) {
    final cmp = major.compareTo(other.major);
    if (cmp != 0) return cmp;
    final cmpMinor = minor.compareTo(other.minor);
    if (cmpMinor != 0) return cmpMinor;
    final cmpPatch = patch.compareTo(other.patch);
    if (cmpPatch != 0) return cmpPatch;
    return _comparePrerelease(prerelease, other.prerelease);
  }

  /// SemVer 预发布优先级：数字标识按数值、字母数字按 ASCII，
  /// 数字低于字母数字，同一前缀下较长的优先级更高；无预发布最高。
  static int _comparePrerelease(String? a, String? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    final aIds = a.split('.');
    final bIds = b.split('.');
    final digit = RegExp(r'^\d+$');
    for (var i = 0; i < aIds.length && i < bIds.length; i++) {
      final aNum = digit.hasMatch(aIds[i]);
      final bNum = digit.hasMatch(bIds[i]);
      if (aNum && bNum) {
        final c = int.parse(aIds[i]).compareTo(int.parse(bIds[i]));
        if (c != 0) return c;
      } else if (aNum) {
        return -1;
      } else if (bNum) {
        return 1;
      } else {
        final c = aIds[i].compareTo(bIds[i]);
        if (c != 0) return c;
      }
    }
    return aIds.length.compareTo(bIds.length);
  }

  bool operator >(Version other) => compareTo(other) > 0;
  bool operator <(Version other) => compareTo(other) < 0;
  bool operator >=(Version other) => compareTo(other) >= 0;
  bool operator <=(Version other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) =>
      other is Version && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, prerelease);

  /// 不带 `v` 前缀与构建元数据的版本串，如 `0.1.0-beta.2`。
  @override
  String toString() =>
      prerelease == null ? '$major.$minor.$patch' : '$major.$minor.$patch-$prerelease';
}
