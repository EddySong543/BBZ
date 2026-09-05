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
- `src/ui/battle_screen_base.tscn`（共享组合）
- `src/ui/battle_screen1.tscn`（Scene1 正式入口）
- `src/ui/battle_screen2.tscn`（Scene2 独立入口）
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

## 2026-07-20 对话收尾补充

### Git 不再重复排障

Windows Codex 沙箱用户与仓库所有者不同会触发 `detected dubious ownership`。固定使用一次性参数，不修改仓库所有权：

```powershell
$Repo = 'D:\Game\BoBoZan\Claude-Code-Game-Studios-cn-localization'
git -c safe.directory=$Repo -C $Repo status -sb
```

仓库使用 HTTPS 远程和 Windows Git Credential Manager。除非 Git 明确报告认证失败，否则不得要求 Eddy 重交 Token、安装 GitHub 插件或重新登录。用户明确说 `commit+push` 后，精确暂存本任务文件、检查缓存区、中文提交、核对远程并直接推送 `origin/main`。完整命令与失败保护见根 `AGENTS.md`。

2026-07-20 收尾实证：首次 push 返回 `Recv failure: Connection was reset`，一次性 HTTP/1.1 重试返回 `Failed to connect to github.com port 443`。这是网络不可达，不是 Credential Manager 或仓库权限问题；四个提交完整保留在本地 `main`，网络恢复后只需重跑 `git push origin main`。

### Godot 崩溃复核结论

- 2026-07-20 前一次 `0x0000000000000058` 读内存弹窗没有留下对应的新 dump 或 WER 事件，不能定位到具体 Godot 原生函数。
- 现存 2026-07-04 dump 对应 Godot 4.7.0 的 `0xc0000005`，不能直接证明 4.7.1 本次弹窗的根因。
- 4.7.1 重新打开后，用户 F6 正常退出；自动 GUT 438/438、1607 断言通过；当日没有 NVIDIA Display/device-lost 事件。
- 若再次出现，保留弹窗和进程，立即读取对应 PID、WER 和新 dump；不得先关闭用户 Godot。

## 2026-07-20 Battle Screen / 道具 UI 会话结论

### 已验证基线

- 全量 GUT：40 个脚本、444 个测试、1639 条断言通过。
- Battle Screen 真实点击探针确认替补头像可进入主动换人态。
- h04 敌我头像镜像截图确认 P2 遮罩与 P1 严格水平对称。
- 主动技能紫色按钮、顶部 HUD、回合提示和新道具框均完成窗口截图自检。

### 长期工程约束

- UI 换皮默认只授权视觉层；点击、切换、状态门、计时与现有动画均视为成熟契约，除非 Eddy 点名，否则不得删改。
- `TextureRect.flip_h` 会影响传入 CanvasItem shader 的 UV。非对称摆位头像做敌我镜像时，遮罩必须在 shader 局部坐标中反翻 x；只翻纹理会出现 h04 那类三角错裁。
- 稀有度框采用单一 `assets/ui/item_frame.png` 明暗母版，由 `canvas_ui_item_frame_palette.gdshader` 映射蓝/紫/金；不得重新复制三张相同位图。
- 英雄图鉴使用图鉴专用头像节点，不再实例化旧 `HeroFrame` 后叠新框；“替换”必须从场景树中消除旧框层。
- 图鉴制作与返工的最终工程合同见 `docs/reports/2026-08-27-codex-production-retrospective.md`：主菜单、战斗及后续入口必须实例化同一个 `codex_screen.tscn`；书本全局居中，侧签通过母版不得重画，固定布局场景化，视觉验收使用无截图运行探针。
- 视觉完成汇报前至少执行一次无截图运行/输入探针，并用几何断言或像素数据检查遮罩、透明边和四角填充；不能只靠源代码推断。

### 编辑器预览与运行画面

当前差异来自三类运行时行为：`TOP_UI_DROP` 位置补偿、程序化创建固定 UI、非 `@tool` HeroFrame 在 `_ready()` 中创建菱形框/遮罩。未来若做所见即所得：

1. 先把固定位置烘焙进 `.tscn`，移除运行时补偿。
2. 为 HeroFrame 增加不触发战斗逻辑的 editor-safe 预览。
3. 把固定程序化 UI 迁入场景树，代码只更新数据和动画。
4. 用独立 `BattleUiPreview` 提供阵容、血量、能量、倒计时和状态预览。

禁止直接给整个 `battle_screen.gd` 加 `@tool`；其 `_ready()` 会启动 BattleCore、计时器、AI、存档和动态节点，编辑器副作用不可接受。
