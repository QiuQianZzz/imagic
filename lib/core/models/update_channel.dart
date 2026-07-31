/// 更新检查渠道。
///
/// 决定检查更新时在哪些 GitHub Release 中寻找候选版本：
/// - [stable]：仅无预发行后缀（beta/rc/alpha）的正式版，稳定可靠
/// - [all]：正式版 + 预发行版，取最新；预发行版可能不稳定
enum UpdateChannel {
  stable('正式版'),
  all('所有版本');

  final String label;

  const UpdateChannel(this.label);
}
