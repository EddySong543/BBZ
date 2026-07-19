# BBZ Codex 工作规则

## Godot 启动铁律

Codex 自动化任务必须通过 `tools/run_godot.ps1` 启动 Godot，不得直接调用 exe，也不得替用户启动常驻 `--editor`。

用户会手动启动Godot编辑器并使用F6检查、测试游戏。**Codex绝对不得关闭任何预先存在的Godot进程**。父进程已退出、`MainWindowHandle=0`、窗口标题为空或内存占用较高，都不能证明它是孤儿进程。若自动化与现有Godot发生冲突，停止自己的任务并向用户汇报，不得执行 `Stop-Process`、`taskkill` 或其他外部进程清理。

2026-07-19纠错：Codex曾把用户手动启动的PID 16456和17932误判为孤儿进程并关闭。此判断错误，不得重犯。`0x0000000000000058`读内存错误的底层根因尚未由崩溃转储证明，不能再归因于这两个手动编辑器进程。

统一命令：

```powershell
# 导入
& .\tools\run_godot.ps1 -Mode Import

# 全量 GUT
& .\tools\run_godot.ps1 -Mode Test

# Headless 工具
& .\tools\run_godot.ps1 -Mode Tool -Target 'res://tools/xxx.gd'

# 窗口截图探针（不加 --headless）
& .\tools\run_godot.ps1 -Mode Probe -Target 'res://tools/xxx_probe.tscn'
```

启动器固定使用：

- Godot：`D:\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`
- 项目根：启动器根据自身位置解析，不依赖调用时 cwd。
- GUT：始终带 `-gexit`。
- 截图探针：绝不使用 `--headless`。
- 自动化：等待明确退出；超时只允许终止启动器自己通过 `Start-Process` 创建并持有的 `$GodotProcess`。
- 崩溃：抑制Windows应用程序错误对话框，改为退出码和日志，避免无人值守时永久卡住。

用户手动打开的Godot编辑器必须保持运行，供用户F6验收；除非用户明确点名某个PID并要求关闭，否则Codex不得关闭。

## 工作区保护

- 不覆盖、回滚或提交用户未授权的既有修改。
- 当前 Battle UI 中断文件以 `production/session-state/active.md` 和 `docs/operations/PROJECT-TAKEOVER.md` 为准。
- commit/push 前精确暂存本任务文件；不得使用笼统的 `git add .`。
