# Imagic

一款基于 Flutter 构建的 Windows 桌面图片查看器，采用 Material Design 3 视觉风格，原生组件实现，无 UI 组件库依赖。

## 特性

- **多格式支持**：JPEG / PNG / BMP / GIF / WebP / PPM / PGM / PBM / TGA / SVG
- **高性能解码**：PNG 由引擎 C++ 解码器直接处理，其他光栅格式在 Isolate 中解码重编码为 PNG，避免 UI 卡顿
- **平滑缩放动画**：缩放操作以视口中心为焦点播放 200ms easeOutCubic 动画，平移直接透传
- **MD3 动态主题**：基于种子色生成完整 ColorScheme，支持系统/浅色/深色模式、12 预设色 + 自定义色相
- **可定制快捷键**：4 个核心动作（上一张 / 下一张 / 切换全屏 / 退出全屏）支持重新绑定与冲突检测
- **自绘标题栏**：隐藏系统标题栏，可选 Windows 或 macOS 风格窗口控件
- **多种图片背景**：栅格 / 深色栅格 / 纯白 / 纯黑 / 浅灰 / 灰色 / 深灰
- **拖拽打开**：从资源管理器拖入文件直接打开
- **同目录浏览**：自动加载相邻图片，菜单栏按钮 / 悬浮按钮 / 键盘箭头切换

## 构建与运行

```bash
# 安装依赖
flutter pub get

# 运行（Windows 桌面）
flutter run -d windows

# 打包 MSIX
dart run msix:create
```

要求：Flutter 3.x + Dart 3.9+，已配置 Windows 桌面开发环境。

## 项目结构

```
lib/
├── main.dart                      # 入口：初始化窗口、加载设置、解析命令行参数
├── app.dart                       # MaterialApp + MultiProvider 注入
├── core/                          # 核心基础设施
│   ├── constants/                 # 常量与枚举（背景类型、格式、窗口样式等）
│   ├── services/                  # 设置持久化服务（SharedPreferences）
│   ├── shortcuts/                 # 快捷键动作定义
│   ├── theme/                     # MD3 主题构建
│   └── utils/                     # 全屏、窗口控制、背景绘制、按键标签
├── services/                      # 跨功能公共服务（文件、编解码）
├── models/                        # 通用数据模型
└── features/                      # 业务功能（按特性纵向切分）
    ├── browser/                   # 文件浏览（预留）
    ├── menu/                      # 顶部菜单栏
    ├── settings/                  # 设置中心
    └── viewer/                    # 图片查看
```

详细架构说明见 [docs/架构设计.md](docs/架构设计.md)。

## 文档

- [架构设计](docs/架构设计.md) — 技术栈、项目结构、核心模块、数据流
- [功能设计](docs/功能设计.md) — 已实现功能、支持格式、快捷键、规划中功能
- [UI 设计](docs/UI设计.md) — 布局、组件、主题系统、间距规范

## 技术栈

| 层面 | 选型 |
|------|------|
| 框架 | Flutter (Windows Desktop) |
| 语言 | Dart 3.9+ |
| 状态管理 | Provider 6.1 |
| 图片编解码 | image 4.5（Isolate） |
| SVG 渲染 | flutter_svg 2.3 |
| 窗口管理 | window_manager 0.4 |
| 偏好存储 | shared_preferences 2.5 |
| 打包分发 | msix 3.16 |
