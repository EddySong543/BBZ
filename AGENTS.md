# BBZ Codex 工作规则

## Godot 启动铁律

Codex 自动化任务必须通过 `tools/run_godot.ps1` 启动 Godot，不得直接调用 exe，也不得启动常驻 `--editor`。

原因：2026-07-19 曾有另一个对话用 `--editor` 启动后父进程退出，遗留无窗口孤儿进程 PID 16456；该进程占用约 2.5 GB 私有内存并触发 `0x0000000000000058` 读内存应用程序错误。

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
- 自动化：等待明确退出；超时只终止本次启动的Godot进程。
- 崩溃：抑制Windows应用程序错误对话框，改为退出码和日志，避免无人值守时永久卡住。

如果用户需要亲自打开Godot编辑器，可以手动启动；Codex不得用自动化命令打开常驻编辑器。

## 工作区保护

- 不覆盖、回滚或提交用户未授权的既有修改。
- 当前 Battle UI 中断文件以 `production/session-state/active.md` 和 `docs/operations/PROJECT-TAKEOVER.md` 为准。
- commit/push 前精确暂存本任务文件；不得使用笼统的 `git add .`。
