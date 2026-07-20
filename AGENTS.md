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

## Git 提交与推送固定方法

仓库事实固定为：

- 仓库根：`D:\Game\BoBoZan\Claude-Code-Game-Studios-cn-localization`
- 远程：`origin = https://github.com/EddySong543/BBZ.git`
- 分支：`main`
- 提交身份：`EddySong543 <jmsong543@gmail.com>`
- HTTPS 认证：Windows Git Credential Manager（`credential.helper=manager`）。凭据已由用户环境管理；除非 Git 明确返回认证失败，否则不得要求用户重新提供 Token、安装 GitHub 插件或重新登录。

Codex 沙箱账户可能因为仓库属于 Windows 用户 `Edzzz` 而报 `detected dubious ownership`。不要在这里卡住，也不要修改仓库所有权。每条 Git 命令直接使用一次性安全目录参数：

```powershell
$Repo = 'D:\Game\BoBoZan\Claude-Code-Game-Studios-cn-localization'
git -c safe.directory=$Repo -C $Repo status --short
```

用户明确要求 `commit+push` 时按以下顺序执行：

```powershell
$Repo = 'D:\Game\BoBoZan\Claude-Code-Game-Studios-cn-localization'

# 1. 检查范围；存在其他任务改动时保留，不得顺手提交。
git -c safe.directory=$Repo -C $Repo status --short
git -c safe.directory=$Repo -C $Repo diff -- <本任务文件...>

# 2. 只暂存本任务的明确文件。禁止 git add . 和 git add -A。
git -c safe.directory=$Repo -C $Repo add -- <本任务文件...>

# 3. 提交前检查暂存内容。
git -c safe.directory=$Repo -C $Repo diff --cached --check
git -c safe.directory=$Repo -C $Repo diff --cached --stat
git -c safe.directory=$Repo -C $Repo diff --cached --name-status

# 4. 提交。
git -c safe.directory=$Repo -C $Repo commit -m '<中文提交说明>'

# 5. 核对远程后推送 main。
git -c safe.directory=$Repo -C $Repo remote get-url origin
git -c safe.directory=$Repo -C $Repo push origin main

# 6. 验证本地与远程状态并汇报提交哈希。
git -c safe.directory=$Repo -C $Repo status -sb
git -c safe.directory=$Repo -C $Repo log -1 --oneline
```

执行约束：

- `push` 需要网络或用户凭据访问时，直接申请/使用必要的提权执行，不要改用陌生认证方案反复试错。
- 若远程领先、发生 non-fast-forward、冲突或认证明确失败，停止并汇报；有未提交用户改动时不得擅自 `pull --rebase`、stash、reset 或强推。
- 提交成功但推送失败时，提交仍安全保留在本地；汇报提交哈希和 Git 原始错误，不得重复创建相同提交。
- 推送完成的判据是 `git status -sb` 不再显示相对 `origin/main` 的 `ahead N`；未跟踪或未提交的其他任务文件可以继续存在，但必须单独汇报。
- `Recv failure: Connection was reset` 或 `Failed to connect to github.com port 443` 是网络链路故障，不是认证失败。可用一次性 `-c http.version=HTTP/1.1` 温和重试一次；仍失败则停止，保留本地提交并汇报 `ahead N`，不得改 SSH、Token、远程地址或反复生成提交。
