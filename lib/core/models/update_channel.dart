/// 更新检查渠道。
///
/// 决定检查更新时在哪些 GitHub Release 中寻找候选版本：
/// - [stable]：仅无预发行后缀（beta/rc/alpha）的正式版
/// - [beta]：仅带预发行后缀的测试版
/// - [all]：正式版与测试版全部参与
enum UpdateChannel {
  stable('正式版'),
  beta('测试版'),
  all('所有版本');

  final String label;

  const UpdateChannel(this.label);
}
