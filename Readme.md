# Windows Terminal 右键菜单（Scoop）

为文件夹和文件夹空白处添加 Windows Terminal 菜单，支持普通启动和管理员启动。

优先检测 `%USERPROFILE%\scoop\apps\windows-terminal`，也支持通过 `SCOOP` 环境变量指定安装位置；未找到 Scoop 安装时尝试 Microsoft Store 版本。

## 安装

先安装并运行一次 Windows Terminal，然后在**当前用户的管理员 PowerShell 7** 中进入本仓库执行：

```powershell
.\install.ps1 -Layout Default
```

Default 使用 CommandStore 子菜单，安装时会显示 `Registration mode: CommandStore-v1`。文件夹入口使用 `%1\.`，空白处使用 `%V\.`，配置文件通过 GUID 选择。

本机已由用户确认：改用此方式并在本机运行脚本后，Directory Opus 中的菜单恢复正常。此结果不代表所有 Windows/Opus 版本均已验证。

### 菜单布局

- `Default`：普通和管理员两组子菜单，每组列出可用配置。
- `Flat`：将各配置的普通和管理员命令直接放在右键菜单中。
- `Mini`：只提供默认配置的普通和管理员入口。

![Default 布局](default.png)

![Flat 布局](flat.png)

![Mini 布局](mini.png)

切换布局前先卸载原布局，例如从 Default 切换到 Mini：

```powershell
.\uninstall.ps1 -Layout Default
.\install.ps1 -Layout Mini
```

## 卸载与重装

在管理员 PowerShell 7 中执行，`Layout` 应与已安装的布局一致：

```powershell
.\uninstall.ps1 -Layout Default
```

需要重装时，再运行对应的 `install.ps1` 命令。卸载只处理本项目的菜单和缓存，不卸载 Windows Terminal，也不删除其配置。

## 修改范围

- 菜单入口位于 `HKCU\Software\Classes\Directory\shell` 和 `Directory\Background\shell`。
- Default 命令位于 `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell`，以 `WindowsterminalShellScoop.<用户 SID>.` 区分所属用户。安装及删除这些命令需要管理员权限。
- `RegistrationMode = CommandStore-v1` 和非空的 `SubCommands` 可用于核对 Default 是否已安装。安装脚本会检查命令引用是否存在。
- 缓存位于 `%LOCALAPPDATA%\windowsterminal-shell-scoop\Cache`。旧版放在共享 `WindowsApps\Cache` 下的文件不会被自动删除。
- 管理员入口通过 Windows Script Host 的辅助脚本调用 `runas`，需要 Windows Script Host 可用，并由用户确认 UAC。
- 历史机器级菜单不会被盲目删除；如果检测到冲突，脚本会停止并提示检查。

## 验证

```powershell
.\verify-registration.ps1
```

执行 PowerShell 语法和隔离注册验证，覆盖三种布局、普通/管理员入口和文件夹参数，不修改实际注册表。它不能代替 Explorer 或 Directory Opus 中的实际点击测试。

## 文件

- `install.ps1`：安装菜单。
- `uninstall.ps1`：卸载当前布局及所属 CommandStore 命令。
- `verify-registration.ps1`：隔离验证。
- 三张 PNG：布局示例。
- `LICENSE`：保留原项目许可和版权信息。
