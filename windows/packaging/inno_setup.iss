; Imagic Inno Setup 7.x 脚本
; 适用 Inno Setup 7.0.2 及以上稳定版（https://jrsoftware.org/isdl.php）
;
; 用法（在项目根目录执行）：
;   1. 先构建 Flutter Windows 发布版：flutter build windows --release
;   2. 调用 ISCC 编译：iscc windows\packaging\inno_setup.iss
;   3. 产物输出到 dist\Imagic-<version>-setup.exe
;
; 设计要点：
;   - Per-user 安装（PrivilegesRequired=lowest），不弹 UAC，写入 HKCU
;   - 与应用内 windows_registry.dart 保持同一套注册表结构（ProgId=Imagic.Image）
;   - 文件关联 / 开机自启动：默认勾选；桌面快捷方式：默认不勾选
;   - ChangesAssociations=yes 让安装/卸载后资源管理器自动刷新关联

#define MyAppName "Imagic"
; 版本号默认对齐 pubspec.yaml；CI 中可通过 iscc 命令行覆盖：
;   iscc /DMyAppVersion=0.1.0 /DMyAppVersionFile=0.1.0-beta.1 inno_setup.iss
; MyAppVersion 用于 Windows 版本属性（需 x.y.z 格式），
; MyAppVersionFile 用于安装包文件名（可含 beta/rc 后缀）。
#ifndef MyAppVersion
  #define MyAppVersion "0.1.0"
#endif
#ifndef MyAppVersionFile
  #define MyAppVersionFile "0.1.0"
#endif
#define MyAppPublisher "QiuQianZzz"
#define MyAppExeName "imagic.exe"
; Flutter Windows Release 产物目录（相对脚本文件位置）
#define MyAppSourceDir "..\..\build\windows\x64\runner\Release"

[Setup]
; AppId 在同一应用的所有版本中保持稳定，不要改
AppId={{8E1BDA7C-4F2B-4D9A-9C7E-1A2B3C4D5E6F}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL=https://github.com/QiuQianZzz/imagic
AppSupportURL=https://github.com/QiuQianZzz/imagic/issues
AppUpdatesURL=https://github.com/QiuQianZzz/imagic/releases

; Per-user 安装：{autopf} 解析为 %LOCALAPPDATA%\Programs\<AppName>
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

; 不弹 UAC，允许覆盖安装到 per-user 目录
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

; 输出与图标
OutputDir=..\..\dist
OutputBaseFilename=Imagic-{#MyAppVersionFile}-setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

; 压缩与样式
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern

; 仅 64 位
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; 安装/卸载后通知 Shell 刷新文件关联
ChangesAssociations=yes

[Languages]
Name: "chinesesimp"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
; 默认勾选
Name: "fileassoc"; GroupDescription: "系统集成："; Description: "将图片文件关联到 Imagic（.jpg/.jpeg/.png/.bmp/.gif/.webp/.ppm/.pgm/.pbm/.tga/.svg）"
Name: "autostart"; GroupDescription: "系统集成："; Description: "开机自启动 Imagic"
; 默认不勾选
Name: "desktopicon"; GroupDescription: "附加选项："; Description: "在桌面创建快捷方式"; Flags: unchecked

[Files]
; 递归拷贝 Flutter Release 产物（含 dll、data、assets）
Source: "{#MyAppSourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{userdesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
; ---- ProgId 节点（无论是否勾选 fileassoc 都写，方便应用内开关后续启用）----
Root: HKCU; Subkey: "Software\Classes\Imagic.Image"; ValueType: string; ValueName: ""; ValueData: "Imagic 图片查看器"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\Imagic.Image\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\Imagic.Image\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Flags: uninsdeletekey

; ---- 扩展名 -> ProgId 映射（仅当勾选 fileassoc 时写入）----
Root: HKCU; Subkey: "Software\Classes\.jpg";  ValueType: string; ValueName: ""; ValueData: "Imagic.Image"; Flags: uninsdeletevalue uninsdeletekeyifempty; Tasks: fileassoc
Root: HKCU; Subkey: "Software\Classes\.jpeg"; ValueType: string; ValueName: ""; ValueData: "Imagic.Image"; Flags: uninsdeletevalue uninsdeletekeyifempty; Tasks: fileassoc
Root: HKCU; Subkey: "Software\Classes\.png";  ValueType: string; ValueName: ""; ValueData: "Imagic.Image"; Flags: uninsdeletevalue uninsdeletekeyifempty; Tasks: fileassoc
Root: HKCU; Subkey: "Software\Classes\.bmp";  ValueType: string; ValueName: ""; ValueData: "Imagic.Image"; Flags: uninsdeletevalue uninsdeletekeyifempty; Tasks: fileassoc
Root: HKCU; Subkey: "Software\Classes\.gif";  ValueType: string; ValueName: ""; ValueData: "Imagic.Image"; Flags: uninsdeletevalue uninsdeletekeyifempty; Tasks: fileassoc
Root: HKCU; Subkey: "Software\Classes\.webp"; ValueType: string; ValueName: ""; ValueData: "Imagic.Image"; Flags: uninsdeletevalue uninsdeletekeyifempty; Tasks: fileassoc
Root: HKCU; Subkey: "Software\Classes\.ppm";  ValueType: string; ValueName: ""; ValueData: "Imagic.Image"; Flags: uninsdeletevalue uninsdeletekeyifempty; Tasks: fileassoc
Root: HKCU; Subkey: "Software\Classes\.pgm";  ValueType: string; ValueName: ""; ValueData: "Imagic.Image"; Flags: uninsdeletevalue uninsdeletekeyifempty; Tasks: fileassoc
Root: HKCU; Subkey: "Software\Classes\.pbm";  ValueType: string; ValueName: ""; ValueData: "Imagic.Image"; Flags: uninsdeletevalue uninsdeletekeyifempty; Tasks: fileassoc
Root: HKCU; Subkey: "Software\Classes\.tga";  ValueType: string; ValueName: ""; ValueData: "Imagic.Image"; Flags: uninsdeletevalue uninsdeletekeyifempty; Tasks: fileassoc
Root: HKCU; Subkey: "Software\Classes\.svg";  ValueType: string; ValueName: ""; ValueData: "Imagic.Image"; Flags: uninsdeletevalue uninsdeletekeyifempty; Tasks: fileassoc

; ---- 开机自启动（仅当勾选 autostart 时写入，值名 Imagic 与 windows_registry.dart 对齐）----
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "Imagic"; ValueData: """{app}\{#MyAppExeName}"""; Flags: uninsdeletevalue; Tasks: autostart

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
