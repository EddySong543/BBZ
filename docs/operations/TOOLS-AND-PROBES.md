# 工具与探针运行规范

更新时间：2026-07-19

## 清点结果

`tools/` 顶层 GDScript 按实际行为分为：

| 类别 | 数量 | 默认权限 | 说明 |
|---|---:|---|---|
| 视觉探针 | 43 | 可运行 | 加载真实场景并截图；必须带窗口 |
| 联机探针 | 6 | 条件运行 | 会占用本机端口，部分需要双进程 |
| 写入/资源管线工具 | 22 | 禁止误跑 | 会生成、覆盖或导入项目资源，不属于只读探针 |
| Headless 检查/模拟 | 4 | 可运行 | 不依赖画面，用于扫描、模拟或数据检查 |
| 预览/辅助工具 | 9 | 先读说明 | 行为不完全一致，运行前读文件头注释 |

分类依据是实际文件行为，不依赖文件名中的 `probe`、`preview` 或 `runner`。

## 标准启动方式

Codex及无人值守任务统一使用：

```powershell
& .\tools\run_godot.ps1 -Mode Import
& .\tools\run_godot.ps1 -Mode Test
& .\tools\run_godot.ps1 -Mode Tool -Target 'res://tools/xxx.gd'
& .\tools\run_godot.ps1 -Mode Probe -Target 'res://tools/xxx_probe.tscn'
```

禁止Codex直接启动常驻 `--editor`。统一启动器会等待自己启动的Godot进程，超时只清理该进程，并将崩溃转为退出码和日志，避免Windows应用程序错误框永久卡住。

以下直接命令只供人工排障理解；自动化不得绕过统一启动器。

Godot 可执行文件：

```text
D:\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe
```

PowerShell 运行 Headless 工具：

```powershell
& "D:\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Game\BoBoZan\Claude-Code-Game-Studios-cn-localization" --script res://tools/<工具>.gd
```

PowerShell 运行截图探针：

```powershell
& "D:\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --path "D:\Game\BoBoZan\Claude-Code-Game-Studios-cn-localization" res://tools/<探针>.tscn
```

截图探针不得使用 `--headless`。GUT 必须带 `-gexit`。新图片引用前先运行一次 `--headless --path <项目根> --import`。

## 截图输出

新标准由 `tools/probe_output.gd` 统一处理：

- 默认目录：Godot 的 `user://probe-output`。
- 启动时会在终端打印实际绝对目录。
- 可用环境变量 `BBZ_PROBE_OUTPUT` 覆盖。
- 可在 Godot 用户参数中传 `probe-output=<绝对目录>` 覆盖。
- 输出目录不存在时自动创建。

已迁移全部6个失效的 Claude 临时 UUID 探针：cursor、gallery、identity hover、profile、settings、tip。故事探针也已使用该输出入口。

仍有40个旧工具写到 `D:/Game/BoBoZan/`。该目录在当前唯一开发机上有效、位于仓库外，不会触发 Godot 导入；它们属于低优先级可移植性债，不是失效工具。新工具不得继续复制这种写法，旧工具在实际再次使用时迁移到统一入口。

## 存档与用户数据

- Profile 探针通过 `PlayerProfile.save_enabled=false` 禁止落盘。
- Story 探针把 `story_progress_probe.cfg` 写入统一探针输出目录，不再删除或覆盖真实 `user://story_progress.cfg`。
- 任何新探针不得直接删除真实玩家存档；应提供可注入路径或先做可恢复备份。

## 联机探针

- `net_probe`、`net_battle_probe`、`lan_probe`：真实本机 Socket 验证，运行后应关闭传输。
- `lan_duo_probe`：必须带窗口并启动两个进程，加入方晚约3秒；占用47777（对局）和47778（发现）。
- 端口被占时应视为“环境未就绪”，不可通过杀死未知进程强行抢占。
- 联机功能当前是地基状态；这些探针只证明本机协议和大厅链路，不代表公网部署、安全运维或正式服务器已经完成。

## 写入型工具红线

以下名称族默认视为会修改资源：

- `import_*`
- `gen_*`
- `fix_*`
- `img_*`（多数会写目标图片）

运行前必须确认输入、输出和覆盖目标。它们不得作为“只读项目审计”或普通截图探针批量执行。

## 当前已知例外

- `tools/_tmp_sz.gd` 与 `.uid` 是接管前未跟踪的 Battle UI 临时文件，当前不判断去留。
- `tools/diamond_probe.gd` 含接管前未完成修改，当前不纳入工具整理提交。
- 老工具中的 `D:/Game/BoBoZan/` 输出目前可用；若开发目录迁移到其他磁盘，需要按使用批次迁移。
