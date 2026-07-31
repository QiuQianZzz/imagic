# Imagic 打包说明

Imagic 提供三种 Windows 分发形态：**EXE 安装包**、**MSIX 安装包**、**绿色版**。三者共享同一份 Flutter Release 产物，仅在外层封装与系统集成方式上有所差异。

## 0. 公共前置

```powershell
# 切换到项目根目录
cd d:\Desktop\flutter\imagic

# 构建 Windows Release 产物（产物在 build\windows\x64\runner\Release\）
flutter build windows --release
```

产物目录结构：

```
build\windows\x64\runner\Release\
├── imagic.exe
├── flutter_windows.dll
└── data\        # flutter 资源、assets、字体等
```

后续三种打包方式都基于这个 Release 目录。

---

## 1. EXE 安装包（Inno Setup 7.x）

适用场景：**默认分发方式**。Per-user 安装，不弹 UAC，自带文件关联与开机自启动选项。

### 1.1 准备工具

下载并安装 Inno Setup 7.0.2 或以上稳定版：<https://jrsoftware.org/isdl.php>

安装后 `iscc.exe` 默认在 `C:\Program Files (x86)\Inno Setup 7\`，需要加入 PATH 或使用全路径调用。

### 1.2 编译安装包

```powershell
# 在项目根目录执行
iscc windows\packaging\inno_setup.iss
```

产物：`dist\Imagic-<version>-setup.exe`

### 1.3 安装行为

| 项 | 默认 | 说明 |
| --- | --- | --- |
| 安装目录 | `%LOCALAPPDATA%\Programs\Imagic` | Per-user，无需管理员权限 |
| 开始菜单快捷方式 | 总是创建 | `Imagic` + `卸载 Imagic` |
| 桌面快捷方式 | 不勾选 | 用户可选 |
| 文件关联 | 默认勾选 | 关联 `.jpg/.jpeg/.png/.bmp/.gif/.webp/.ppm/.pgm/.pbm/.tga/.svg` 到 Imagic |
| 开机自启动 | 默认勾选 | 写入 `HKCU\...\Run\Imagic` |

### 1.4 与应用内开关的关系

Inno 写入的注册表结构与 [windows_registry.dart](../lib/core/utils/windows_registry.dart) 完全对齐：

- ProgId：`HKCU\Software\Classes\Imagic.Image`
- 命令：`"<安装目录>\imagic.exe" "%1"`
- 自启动值名：`Imagic`

因此用户在安装时未勾选，后续也可在 **设置 → 常规 → 系统集成** 中打开；反之亦然。卸载会清理 Inno 写入的项，应用内开关在下次启动时会重新检测并自愈。

---

## 2. MSIX 安装包

适用场景：**后续通过 GitHub Actions 签名分发**。本地开发可生成未签名包用于自测。

### 2.1 配置

`pubspec.yaml` 已配置 `msix_config`：

```yaml
msix_config:
  display_name: Imagic
  publisher_display_name: QiuQianZzz
  identity_name: QiuQianZzz.Imagic
  publisher: CN=QiuQianZzz
  msix_version: 1.0.0.0
  logo_path: windows/runner/resources/app_icon.ico
  capabilities: runFullTrust
  store: false
```

### 2.2 本地未签名打包（开发自测）

```powershell
# 生成未签名 MSIX（仅本地自测，需开发者模式或 sideload 权限安装）
flutter pub run msix:create --build-windows false
```

产物：`build\windows\msix\imagic-<version>.msix`（默认按 pubspec 的 `msix_version` 生成）

未签名 MSIX 安装限制：

- 需要在 `Windows 设置 → 隐私和安全性 → 开发者选项` 中开启"开发者模式"或 sideload
- 无法直接通过双击安装，需用 PowerShell：

  ```powershell
  Add-AppxPackage -Path imagic.msix
  ```

### 2.3 签名打包（生产分发）

签名流程在 **GitHub Actions** 的 `release.yml` 中自动完成，本地无需准备证书：

1. 生成自签名证书（或申请正规代码签名证书，EV 证书可直接商店分发，OV 证书需要用户信任根证书）
2. 将证书导出为 PFX，Base64 编码后存入 GitHub Secrets：`MSIX_CERT`、`MSIX_CERT_PASSWORD`
3. 推送 `v*` 标签触发构建，workflow 会自动解码证书、用 `--install-certificate false` 跳过证书安装提示完成签名（未配置 Secrets 时回退为插件自签的测试证书）
4. 产物 `imagic-<version>.msix` 随 GitHub Release 上传

### 2.4 MSIX 文件关联（待办）

当前 MSIX 配置未声明 `file_extension`，安装时不会自动关联文件类型。后续可通过在 `msix_config` 中添加：

```yaml
msix_config:
  # ... 其他配置
  file_extension: ".jpg,.jpeg,.png,.bmp,.gif,.webp,.ppm,.pgm,.pbm,.tga,.svg"
```

声明后 MSIX 安装会通过 AppxManifest 自动注册文件关联，**与应用内开关共用同一套 ProgId**。

### 2.5 上架 Microsoft Store（可选）

若后续需要上架商店：

1. 在 Partner Center 创建应用，获取保留的包名与发布者身份
2. 修改 `identity_name` 和 `publisher` 为商店保留值（形如 `CN=...`）
3. 设置 `store: true`
4. 重新打包并上传

---

## 3. 绿色版（免安装）

适用场景：**便携分发、U 盘携带、临时运行**。无注册表依赖，但文件关联与自启动需应用内手动开启。

### 3.1 制作

```powershell
# 1. 构建 Release 产物
flutter build windows --release

# 2. 拷贝整个 Release 目录到一个干净的文件夹
Copy-Item -Recurse `
  build\windows\x64\runner\Release `
  dist\Imagic-<version>-portable

# 3. 压缩成 zip
Compress-Archive `
  -Path dist\Imagic-<version>-portable\* `
  -DestinationPath dist\Imagic-<version>-portable.zip

# 4. 删除中间目录
Remove-Item -Recurse dist\Imagic-<version>-portable
```

产物：`dist\Imagic-<version>-portable.zip`

> CI 中的绿色版产物命名略有不同（`imagic-<version>-windows.zip`，见 [release.yml](../.github/workflows/release.yml)），内容相同。

### 3.2 使用限制

- 解压任意位置即可运行 `imagic.exe`
- **文件关联**：解压状态下默认不关联。可在 **设置 → 常规 → 系统集成** 中打开"文件关联"开关，应用内会写入 `HKCU\Software\Classes\...`（与安装版共用同一套注册表结构）
- **开机自启动**：同样可在设置中开启，写入 `HKCU\...\Run\Imagic`
- 注意：**绿色版路径变更后**，需在设置中关闭再开启关联/自启动，以刷新注册表中记录的 exe 路径

---

## 4. 三种分发方式对比

| 特性 | EXE (Inno) | MSIX | 绿色版 |
| --- | --- | --- | --- |
| 安装方式 | 双击安装 | Add-AppxPackage / 双击 | 解压即用 |
| 需要管理员权限 | 否 | 否（签名后可双击） | 否 |
| 自动文件关联 | 安装时可勾选 | 待声明 `file_extension` | 需应用内开关 |
| 自动开机自启 | 安装时可勾选 | 需应用内开关 | 需应用内开关 |
| 卸载干净度 | 完整卸载 | 完整卸载 | 手动删目录 |
| 沙箱/隔离 | 无 | 有（AppContainer） | 无 |
| 商店分发 | 不支持 | 支持（需上架） | 不支持 |
| 签名要求 | 可不签名 | 必须签名（本地 sideload 除外） | 可不签名 |

---

## 5. CI/CD 建议（GitHub Actions）

当前仓库已配置好发布流水线 [release.yml](../.github/workflows/release.yml)，推送 `v*` 标签即自动发布：

```
.github/workflows/release.yml
├── 触发：tag 推送 v* 或 workflow_dispatch（手动指定版本）
├── job: release
│   ├── actions/checkout（fetch-depth: 0，取全部 tag）
│   ├── 解析版本：版本号取自 tag（去掉 v 前缀），识别 beta/rc 预发行标记
│   ├── 同步 pubspec 版本号为 tag 版本
│   ├── subosito/flutter-action@v2（stable 3.44.2，带 SDK 缓存）
│   ├── flutter build windows --release
│   ├── 生成绿色版：Compress-Archive 压缩 Release 目录
│   ├── 生成 MSIX：flutter pub run msix:create（Secrets 证书签名）
│   ├── 安装 Inno Setup 7 并编译 EXE 安装包
│   ├── 生成 release notes：正式版取 CHANGELOG 对应版本块，预发行版取提交标题
│   └── softprops/action-gh-release 上传三种产物并创建 Release
```

签名密钥统一通过 GitHub Secrets 管理，本地无需持有任何证书。

---

## 6. 常见问题

### 6.1 EXE 安装时提示"文件被占用"

确保 Imagic 已完全退出后再安装（可先在任务管理器中确认没有 `imagic.exe` 进程）。

### 6.2 文件关联不生效

- 检查 `设置 → 常规 → 系统集成 → 文件关联` 开关状态
- 在 Windows 设置中查看默认应用是否被其他程序抢占
- 资源管理器未刷新可重启 explorer.exe 或注销重登

### 6.3 MSIX 安装失败 `0x80073CFF`

未签名 MSIX 需要开发者模式。 PowerShell 执行：

```powershell
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /t REG_DWORD /f /v "AllowDevelopmentWithoutDevLicense" /d 1
```

### 6.4 绿色版更换路径后关联失效

注册表记录的是 exe 绝对路径，路径变更后需在设置中关闭再开启文件关联。
