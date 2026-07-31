# Imagic UI 设计

## 1. 设计基调

- **视觉风格**：Material Design 3，基于种子色动态生成完整 `ColorScheme`
- **组件实现**：原生 Flutter 组件，无第三方 UI 库
- **字体**：Microsoft YaHei（全字号统一应用）
- **形状语言**：圆角为主，常用半径 8 / 12 / 16 / 20
- **交互反馈**：MD3 状态层（hover / pressed / focused）+ 柔和阴影
- **3D 按压效果**（按键徽章等需突出的元素）：
  - 默认阴影 `blurRadius: 3, offset: (0, 2)`
  - 悬停加深 `blurRadius: 6, offset: (0, 3)` 营造浮起感
  - 按下阴影消失 + 背景切换为 `surfaceContainerHighest` 产生凹陷效果

## 2. 整体布局

应用只有一个主页面 `ViewerScreen`，无路由跳转（设置页通过 `MaterialPageRoute` push 进入）。

```
┌──────────────────────────────────────────────────────────┐
│  菜单栏（48px，自绘标题栏）                              │
│  [Logo] [文件 查看 工具 帮助]  文件名  [←][→][📂]  [─□✕]│
├──────────────────────────────────────────────────────────┤
│                                                          │
│                    图片画布区域                            │
│                                                          │
│   ←悬浮按钮          [图片居中显示]          悬浮按钮→     │
│                                                          │
│                    [还原] (缩放/平移后出现)               │
│                                                          │
├──────────────────────────────────────────────────────────┤
│  状态栏（36px）                                           │
│  2/12  |  245 KB  |  1920×1080  |  JPEG       🔍 85% [⛶]│
└──────────────────────────────────────────────────────────┘
```

### 全屏模式

```
┌──────────────────────────────────────────────────────────┐
│   ┌─────────────────────────────────────┐                │
│   │  [⛶] 按 F11 或 Esc 退出全屏         │  ← 顶部提示条   │
│   └─────────────────────────────────────┘  3秒后消失     │
│                                                          │
│                    图片画布区域                            │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

> 提示条中的快捷键文字（如 `F11`、`Esc`）从当前快捷键绑定动态读取，用户自定义后随之更新。此处为默认值示意。

全屏时菜单栏与状态栏通过 `AnimatedSize`（200ms easeOutCubic）滑出隐藏。

## 3. 菜单栏（AppMenuBar）

固定高度 48px，背景 `surfaceContainerLow`，底部 0.5px `outlineVariant` 分隔线。两套布局可切换：

### 3.1 Windows 风格（默认）

```
[Logo Imagic] [文件 查看 工具 帮助] ──文件名── [←][→][📂] [─][□][✕]
```

- Logo + 菜单区 + 标题区可拖拽窗口
- 右侧窗口控件：最小化 / 最大化（图标随状态切换）/ 关闭
- 关闭按钮悬停变红半透明
- 标题区居中显示文件名，`TextOverflow.ellipsis` 单行省略

### 3.2 macOS 风格

```
[🔴 🟡 🟢] [Logo Imagic] [文件 查看 工具 帮助] ──文件名── [←][→][📂]
```

- 左侧三个 12×12 圆点（红 / 黄 / 绿），悬停显示对应功能图标
- 关闭点悬停红色加深，最小化点悬停黄色加深，最大化点悬停绿色加深
- 无右侧窗口控件

### 3.3 菜单项

`SubmenuButton` 展开下拉菜单，菜单项 `MenuItemButton`：

- 悬停背景：`primary.withValues(alpha: 0.06)`
- 按下/聚焦背景：`primary.withValues(alpha: 0.12)`
- 快捷键文本右对齐显示，颜色 `onSurfaceVariant`
- 分隔线高度 1px

### 3.4 导航按钮

仅在 `hasImage` 时显示：

| 按钮     | 显示条件                      | 图标            |
| -------- | ----------------------------- | --------------- |
| 上一张   | `showNavBarArrows && hasPrev` | `chevron_left`  |
| 下一张   | `showNavBarArrows && hasNext` | `chevron_right` |
| 打开文件 | `showNavBarOpen`              | `folder_open`   |

按钮尺寸 40×48，透明背景 + `InkWell` 涟漪，带 Tooltip。

## 4. 图片画布（ImageCanvas）

### 4.1 空状态

```
        ┌────────────┐
        │   [图标]    │   ← 96×96 圆角容器，surfaceContainerHighest
        └────────────┘
         点击打开图片
        或拖拽文件到此处
```

整个区域可点击（`GestureDetector` + `MouseRegion` 指针变 click），点击调用文件对话框。

### 4.2 有图状态

```
┌──────────────────────────────────────────────┐
│ [CustomPaint 背景层]                          │
│                                              │
│  [←]    ┌──────────────────┐    [→]          │
│         │   InteractiveViewer │              │
│         │   [图片 BoxFit.contain] │           │
│         └──────────────────┘                 │
│                                              │
│              [还原]                          │
└──────────────────────────────────────────────┘
```

层级（Stack）：

1. `CustomPaint` 绘制背景（栅格 / 纯色，由 `ImageBackgroundPainter` 实现）
2. `InteractiveViewer` 承载图片，`boundaryMargin: infinity` 允许任意平移
3. `_ResetOverlay` 还原按钮（缩放/平移非默认时显示，动画滑入）
4. 左右悬浮 `_NavButton`（仅当 `showFloatingArrows` 且有上一张/下一张时显示）

### 4.3 悬浮导航按钮

40×80 圆角矩形，背景 `surfaceContainerHigh.withValues(alpha: 0.85)`，圆角 12，靠左/右居中对齐。

### 4.4 还原浮层

底部居中，胶囊形圆角 20，背景 `surfaceContainerHigh`，含图标 + 文字「还原」。

- 默认状态：`AnimatedSlide` 向下偏移 3 行 + `AnimatedOpacity` 0
- 非默认状态：滑入 + 淡入（350ms easeOutCubic）

## 5. 底部状态栏（ZoomIndicator）

固定高度 36px，背景 `surfaceContainerLow`，顶部 0.5px `outlineVariant` 分隔线，左右内边距 16。

```
[2/12] | [245 KB] | [1920x1080] | [JPEG]              [🔍 85%] [⛶]
```

- 左侧文件信息（仅 `hasImage` 时显示），各项之间用 1×16 竖线分隔
- 进度使用 `FontFeature.tabularFigures` 等宽数字
- 右侧缩放百分比 + 全屏切换按钮
- 文件大小格式化：< 1KB 显示 B，< 1MB 显示 KB，否则显示 MB
- 扩展名 `JPG` 显示为 `JPEG`

## 6. 全屏提示条（FloatingFullscreenHint）

进入全屏后顶部居中浮现，3 秒后自动滑出消失。

- 进入动画：从顶部上方 15% 滑入 + 淡入（350ms easeOutCubic）
- 退出动画：反向滑出 + 淡出（300ms）
- 宽度根据内容自适应，水平居中
- 背景 `surfaceContainerHigh`，圆角 12，含阴影
- 左侧 `fullscreen_exit` 图标（primary 色）+ 提示文字
- `IgnorePointer` 包裹，不拦截画布交互

## 7. 设置页面（SettingsScreen）

### 7.1 整体布局

```
┌──────────────────────────────────────────────────┐
│ [←] [🔧] 设置                                    │  ← 顶部栏 48px
├──────┬───────────────────────────────────────────┤
│ 常规 │                                           │
│ 主题 │           右侧内容区（520px 居中）          │
│ 窗口 │           SingleChildScrollView            │
│ 快捷 │                                           │
│ 备份 │                                           │
│ 关于 │                                           │
│ 更新 │                                           │
└──────┴───────────────────────────────────────────┘
```

- 顶部栏 48px，背景 `surface`，含返回按钮、调谐图标、标题
- 标题区可拖拽窗口
- 左侧 `NavigationRail` 宽 80，显示全部标签，选中项 primary 色
- 右侧内容区固定宽 520，外边距 24

### 7.2 SectionCard 容器

所有设置项卡片统一样式：

- `Card` 0 elevation，圆角 12，`clipBehavior: antiAlias`
- 背景 `surfaceContainerLow`
- 内边距 16
- 标题行：18px primary 图标 + titleMedium primary 文字（w600）
- 内容区左右内边距 8

### 7.3 常规分区

**图片切换** 卡片：3 个 `Switch.adaptive` 开关行（标签 + 右对齐开关）

**图片背景** 卡片：`Wrap` 布局展示 7 个 `_BackgroundChip`：

```
┌────────┐  ┌────────┐  ┌────────┐
│ [预览] │  │ [预览] │  │ [预览] │   ← 72×56 圆角12，ClipRRect 统一裁剪
│  栅格  │  │深色栅格│  │  纯白  │   ← 下方 72 宽标签
└────────┘  └────────┘  └────────┘
```

- 选中：边框 primary 2.5px + 右上角 check_circle 图标 + 文字 primary w600
- 悬停：边框 onSurfaceVariant 0.7 alpha 1.5px
- 默认：边框 outlineVariant 1px
- 预览区域用 `CustomPaint` 实时绘制对应背景

### 7.4 主题分区

**外观** 卡片：`SegmentedButton`（系统 / 浅色 / 深色），右侧 340 宽对齐。

**种子颜色** 卡片：

```
预设
[■][■][■][■][■][■][■][■][■][■][■][■]   ← 56×56 圆角16 色块

自定义
[■][■][➕]                              ← 自定义色块 + 添加按钮
```

- 选中色块：primary 边框 2.5px + 居中 check 图标（颜色根据亮度自动黑/白）
- 自定义色块悬停显示右上角关闭按钮（移除）
- 添加按钮：`surfaceContainerHighest` 背景 + add 图标
- 自定义颜色对话框：48 高色块预览 + 24 高色相滑块（彩虹渐变 track）

**调色板预览** 卡片：5 组 224 宽的色卡（Primary / Secondary / Tertiary / Neutral / Error），每组 4 个色样。

### 7.5 窗口分区

- **窗口大小** 卡片：占位文本
- **窗口控件样式** 卡片：`SegmentedButton`（Windows / macOS）

### 7.6 快捷键分区

每个动作一行，整体悬停背景 `surfaceContainerHighest`：

```
┌──────────────────────────────────────────────────────┐
│  上一张图片              [⚠]  [↺]  [←]               │  ← 悬停行
└──────────────────────────────────────────────────────┘
```

- 行：`InkWell` 圆角 10，左右内边距 12，垂直 8
- 冲突警告：橙色 `warning_amber_rounded` + Tooltip
- 重置按钮：仅自定义项显示，悬停时 primary 色，圆角 6
- 按键徽章（`_KeyCap`）：
  - 默认：`surfaceContainerLow` 背景 + outlineVariant 边框
  - 悬停：primary 边框 + 文字
  - 自定义：tertiary 0.6 边框 + tertiary 文字
  - 3D 阴影：默认 blur 3 / offset (0,2)，悬停 blur 6 / offset (0,3)
  - 字体：monospace w600

**绑定对话框**：

```
┌── 绑定快捷键：上一张图片 ──────────┐
│                                  │
│   [⌨]                            │
│   按下新快捷键...                 │  ← 300×150 圆角12 容器
│   按 Esc 或点击外部取消           │
│                                  │
└──────────────────────────────────┘
```

- 捕获组合键：按下并松开后确认；已按下的修饰键（Ctrl / Alt / Shift / Meta）会实时高亮显示
- 捕获后显示按键徽章；若冲突弹出二次确认对话框（标题含警告图标）

### 7.7 关于分区

居中显示 80×80 圆角图标 + 应用名 + 版本，下方「说明」卡片。

## 8. 主题系统

### 8.1 ColorScheme 生成

```dart
ColorScheme.fromSeed(seedColor: Color(seed), brightness: brightness)
```

种子色默认 `0xFF5B8DEF`，可在设置中更改。MD3 自动生成完整的 primary / secondary / tertiary / neutral / error 色调体系。

### 8.2 主题定制项

| 属性                             | 值                                                                     |
| -------------------------------- | ---------------------------------------------------------------------- |
| `useMaterial3`                   | true                                                                   |
| `scaffoldBackgroundColor`        | colorScheme.surface                                                    |
| `dividerTheme`                   | outlineVariant 0.5 alpha，厚度 0.5                                     |
| `appBarTheme`                    | surface 背景，0 elevation，0.5 scrolledUnderElevation                  |
| `cardTheme`                      | 0 elevation，圆角 12，clipBehavior antiAlias，背景 surfaceContainerLow |
| `dialogTheme`                    | 圆角 20，elevation 3                                                   |
| `popupMenuTheme`                 | 圆角 12，elevation 3，背景 surfaceContainer                            |
| `tooltipTheme`                   | inverseSurface 背景，圆角 6                                            |
| `snackBarTheme`                  | floating，圆角 10                                                      |
| 按钮（Elevated / Filled / Text） | 圆角 8，click 鼠标指针                                                 |
| `inputDecorationTheme`           | filled surfaceContainerHighest，圆角 8，无边框                         |

### 8.3 文本主题

全字号统一使用 Microsoft YaHei 字体，按 MD3 规范定义 display / headline / title / body / label 各级字号与行高。

## 9. 间距与尺寸规范

| 用途                                | 值      |
| ----------------------------------- | ------- |
| 菜单栏高度                          | 48      |
| 状态栏高度                          | 36      |
| 设置顶栏高度                        | 48      |
| NavigationRail 宽度                 | 80      |
| 设置内容区宽度                      | 520     |
| 设置内容区内边距                    | 24      |
| SectionCard 内边距                  | 16      |
| SectionCard 内容左右内边距          | 8       |
| 卡片间距                            | 8       |
| 圆角 - 小（按钮 / 输入框）          | 8       |
| 圆角 - 中（卡片 / 菜单 / 图标容器） | 12      |
| 圆角 - 大（颜色色块）               | 16      |
| 圆角 - 对话框                       | 20      |
| 颜色色块尺寸                        | 56×56   |
| 背景预览尺寸                        | 72×56   |
| 悬浮导航按钮                        | 40×80   |
| 窗口控件按钮（Windows）             | 46×48   |
| macOS 圆点                          | 12×12   |
| 最小窗口尺寸                        | 800×600 |
