# BBZ 项目接管基线

更新时间：2026-07-19

## 事实来源优先级

发生冲突时按以下顺序判断：

1. Eddy 当前明确指令。
2. 当前磁盘代码、Git 状态与可复现测试。
3. `production/session-state/active.md` 当前工作便签。
4. Claude Memory 中仍标记为 CURRENT 的长期经验。
5. 旧设计文档、旧 Session Log 和历史提交。

Memory 是重要参考，但旧 Agent 专用规则、过期版本信息或与当前代码冲突的内容不得直接覆盖当前事实。

## 仓库与运行环境

- GitHub：`EddySong543/BBZ`
- 远程：`https://github.com/EddySong543/BBZ.git`
- 默认分支：`main`
- 接管起点：`9cfc461`
- Godot：Steam 版 4.7.1
- 可执行文件：`D:\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`
- 项目根：`D:\Game\BoBoZan\Claude-Code-Game-Studios-cn-localization`

PowerShell 全量测试命令：

```powershell
& "D:\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --path "D:\Game\BoBoZan\Claude-Code-Game-Studios-cn-localization" --headless -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/.gutconfig.json -gexit
```

截图探针不得加 `--headless`。新图片引用前先使用相同 exe 和 `--headless --path <项目根> --import` 完成导入。

## 当前工作区保护线

接管开始时有一组未完成的 Battle UI 修改。它们不属于接管任务，接管整理不得覆盖、回滚、提交或擅自删除：

- `src/ui/battle_screen.gd`
- `src/ui/battle_screen.tscn`
- `src/ui/components/death_switch_overlay.gd`
- `src/ui/components/hero_frame.gd`
- `src/ui/components/hp_slant_bar.gd`
- `tools/diamond_probe.gd`
- `tools/_tmp_sz.gd` 与对应 `.uid`（未跟踪，待恢复 Battle UI 时确认去留）

## 旧 Agent 处理决定

`.claude/agents` 是 Claude Code Game Studios 的遗留框架，不是 Godot 运行依赖，也不是 Codex 接管依赖。当前决定：

- 不修复、不删除，保留历史溯源。
- 不调用这些 Agent 执行项目工作。
- 若未来重新启用该框架，再从 Git 历史恢复或专项修复。

## 记录体系

- Active：只保留当前任务、中断点、风险和恢复入口。
- Memory：保存长期有效的偏好、经验和项目知识；需检查是否过期。
- Session Log：每个不同项目状态只追加一条简短记录，不再复制完整 Active。
- Git：代码、文档和变更历史的最终可验证依据。

接管前旧记录已原样移动到：

- `production/session-logs/archive/session-log-pre-takeover-20260719.md`
  - SHA-256：`E2DFD91A983F29D7166CBDBC2207F7B87051527EC78E0139280B766F245CE6B7`
- `production/session-logs/archive/active-pre-takeover-20260719.md`
  - SHA-256：`9721477C53ADFAA7633EF6406F921AFF2BFA63619BD43530076BB1F0F5FE8DF2`
- `production/session-logs/archive/session-log-pre-takeover-20260719.zip`
  - SHA-256：`3C446C059BB8C693507D337593F26E8FEC11D81033BA9CC040BC20875D657143`

原始两份文件均未删除或改写，压缩包是附加副本。旧 Session Log 约 180 MiB，主要膨胀原因是 Stop Hook 每次重复追加完整 Active。

## 接管验证基线

- Godot：4.7.1 Steam `a13da4feb`
- GUT：40 个脚本、438 个测试全部通过，1607 条断言通过。
- 视觉探针：`cursor_preview` 成功生成 PNG。
- 故事探针：4 张阶段截图生成，`STORY_PROBE: PASS`，隔离存档运行后不存在。
- 联机探针：本机 ENet `NET_PROBE: PASS`。

Codex 自动验证时使用 `Start-Process -Wait -WindowStyle Hidden` 启动 Godot，以便可靠等待独立进程并取得退出码和日志；手动运行仍可使用前述 PowerShell `&` 模板。

### 2026-07-19 Godot进程误判纠正与自动化保护

用户手动启动了Godot编辑器PID 16456和17932用于F6检查。Codex根据“父进程已退出、MainWindowHandle为0、无窗口标题、内存占用较高”把它们误判为孤儿进程并关闭，这是错误操作。这些指标不足以判断Godot的所有权或是否仍有用途。

纠正规则：用户手动Godot绝对禁止关闭；若影响自动化，Codex只能停止自己的任务并汇报。自动化Godot统一使用 `tools/run_godot.ps1`，启动器超时时只终止它自己通过 `Start-Process` 创建并持有的进程。项目根 `AGENTS.md` 让后续对话继承此规则。

`0x0000000000000058`读内存应用程序错误与上述手动进程之间没有崩溃转储或事件日志可以证明因果关系，底层根因仍未确认。统一启动器只能防止Codex自己的自动化进程因崩溃对话框永久卡住，不能视为已经修复Godot引擎或用户编辑器的原生崩溃。

## Session 收尾约定

当 Eddy 说“结束本次 Session：总结、检查、测试、commit 并 push”时：

1. 检查改动范围，排除无关文件、临时文件与敏感信息。
2. 运行与改动相称的测试。
3. 更新简短 Active 和必要的长期记录。
4. 只暂存本次任务文件，以中文提交说明提交。
5. 确认远程仍为 `EddySong543/BBZ` 后推送当前分支。
6. 汇报提交哈希、测试结果及仍未提交的工作区文件。

未经上述明确指令，不自动 commit 或 push。
