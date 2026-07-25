# BattleScreen 场景预览与双入口重构设计

## 目标

- 将正式入口明确命名为 `battle_screen1.tscn` 与 `battle_screen2.tscn`。
- 两个入口共享同一套战斗 UI、角色、交互和战斗逻辑，但各自在场景文件中静态挂载自己的舞台。
- Godot 编辑器打开任一入口时，直接看到对应 Scene1 / Scene2，不依赖运行时替换。
- BattleScreen 的菱形头像框在编辑器中显示现役样式，不再显示运行时才会被隐藏的旧方框。
- 扫描 `assets/ui` 的使用情况，只形成候选报告，不删除任何素材。

## 结构

```text
battle_screen_base.tscn
├── StageSlot
├── 角色、阴影
├── 共用 HUD / 操作区
└── 共用 battle_screen.gd

battle_screen1.tscn
└── StageSlot/Stage = scene1.tscn

battle_screen2.tscn
├── StageSlot/Stage = scene2.tscn
├── Scene2 PostFX
└── Scene2 角色融光、阴影和倒影开关
```

`battle_screen_base.tscn` 是不可直接运行的组合基座。舞台差异属于入口场景的数据，不再由 `battle_screen.gd` 的 `_enter_tree()` 删除和替换节点。脚本只依赖统一的 `StageSlot/Stage` 接口。

## 头像框预览

`hero_frame.gd` 仅作为独立 UI 组件启用 `@tool`，让 `diamond_mode` 在编辑器安全执行。BattleScreen 主脚本不启用 `@tool`，避免战斗初始化、存档、计时器和动态 UI 在编辑器中运行。

旧回纹方框贴图仍被 BP、资料页和技能卡使用，本轮不删除；修复的是 BattleScreen 的错误预览，不改变其他界面的现有契约。

## 兼容与验收

- 所有正式导航改为进入 `battle_screen1.tscn`。
- Scene2 仅通过 `battle_screen2.tscn` 进入。
- 两个入口的角色几何、战斗状态机和 UI 节点路径保持一致。
- GUT 锁定新文件名、静态舞台和 Scene2 独立参数。
- 必要截图只验证 Scene1 / Scene2 两个入口及现役头像框。
