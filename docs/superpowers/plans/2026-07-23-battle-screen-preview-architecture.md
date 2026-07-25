# BattleScreen 双入口与编辑器预览实施计划

1. 更新回归测试，锁定 `battle_screen1.tscn`、`battle_screen2.tscn` 和静态 `StageSlot/Stage`。
2. 将现有完整场景改为不可直接运行的 `battle_screen_base.tscn`。
3. 建立两个薄入口，分别静态挂载 Scene1 与 Scene2，并保留 Scene2 专属后期和角色参数。
4. 删除 `battle_screen.gd` 的运行时舞台替换接口，统一读取 `StageSlot/Stage`。
5. 为 HeroFrame 增加编辑器安全的菱形预览，BattleScreen 逻辑保持非 `@tool`。
6. 更新正式导航、测试和探针路径。
7. 递归扫描 `assets/ui`，输出“可删候选 / 动态或工具引用 / 正式在用”报告，不执行删除。
8. 通过统一 Godot 启动器导入、运行完整 GUT，并对两个入口做必要截图检查。
