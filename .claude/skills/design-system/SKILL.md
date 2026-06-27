---
name: design-system
description: "维护并执行本项目 UI 视觉设计规范（design/ui-design-system.md = 单一真相源）。做任何 UI 前先读它、按令牌与硬规执行；新增/变更视觉决策时回写它。内置「Design Read + 三拨杆 + 审美≠设计系统」审美刹车，防 AI 模板味。"
argument-hint: "[要做的界面或视觉任务，可选]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, Bash
---

当此技能被调用时（任何 UI 视觉工作——新建 / 重构 / 换皮 / 调色 / 加装饰——之前都先走一遍）：

## 1. 先读真相源
- **必读** `design/ui-design-system.md`（UI 视觉单一真相源：定位 / 材质 / 配色令牌 / 字体 / 形状 / shader 母题 / 硬规 / 逐屏现状 / 工作流）。
- 优先级：`ui-design-system.md` > 记忆 > 旧 `design/ui-brief.md`。与代码冲突时**以代码为准并回写本文档**。
- 扫参考锚：`ref/`（ref12 暗金质感 / ref13·ref14 祥云纹）+ 战斗界面（相对最成熟的现状）。

## 2. 动手前做 Design Read（别直接套默认审美·防模板味）
一句话判断：什么界面 / 面向什么状态玩家（大厅长停留·过场·对战·浏览）/ 有无参考锚与令牌可复用 / 有哪些不能乱来的硬规（§6）。

## 3. 定三拨杆（把"做高级点"拆成可执行方向·参考值见真相源 §0.5）
- 布局变化 LAYOUT：规整网格 ↔ 大胆错落
- 动效强度 MOTION：几乎静止 ↔ 频繁醒目
- 信息密度 DENSITY：极简留白 ↔ 密集

## 4. 守「审美 ≠ 设计系统」的边界
"暗金奇幻"是**审美方向**（锚在参考图 + 令牌），不是要逐条硬编的正式规范。参考图给"手感方向"——**照其神、按本项目令牌（§2）落地**；⛔ 别把风格词包装成正式规范硬编。

## 5. 落地 + 自检 + 回写
- 按令牌实现：精确 hex / 字体整数倍 / 框 shader 配方 / 圆角 / 长矩形必设 aspect。
- 守硬规：UI 不加全屏滤镜 / 战斗 UI 永不动 / 暗≠脏（高饱和深色+亮金高对比+连续质感）/ ⛔ 不做动物·furry·兽化风 / 无障碍（颜色非唯一信号）。
- **截图自检**：带窗口跑 shot-runner（`tools/menu_shot_runner.tscn` / `gallery_shot_runner.tscn` / `item_gallery_shot.tscn` / `battle_shot.tscn`·**不加 --headless**）→ Read PNG →「改→截→再看」迭代 → 最终交 Eddy F6。
- **回写真相源**：新确定 / 变更的视觉决策即时更新 `design/ui-design-system.md`，保持唯一真相。

## 注意
- ⚠ 改 `.claude/` 配置 / `project.godot` / 删文件 = 风险操作，先与用户对齐。
- ⛔ 本作不是网页前端：不套 web 设计系统（Material / shadcn）与 landing-page 模板；走像素奇幻令牌。
