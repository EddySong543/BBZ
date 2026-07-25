# assets/ui 使用情况审计（2026-07-23）

## 结论

- 扫描范围：`assets/ui` 下全部 28 个非 `.import` 文件。
- 高置信度未使用素材：**0 个**。
- 本轮未删除任何素材。

审计同时检查了 `.gd` / `.tscn` 的精确 `res://` 引用、文件名引用，以及工具和文档中的间接线索。当前目录中的每个正式素材都至少存在一条运行时代码或场景引用。

## 用户点名的旧头像框族

这些素材不是 BattleScreen 现役菱形框，但目前仍不能删除：

| 素材 | 当前用途 |
|---|---|
| `hero_avatar_frame.png` | `HeroFrame` 方框模式、个人资料大头像、技能卡 |
| `hero_avatar_frame_enemy.png` | `HeroFrame` 敌方方框模式、敌方技能卡 |
| `hero_avatar_frame_atk.png` | BP / HeroCard 进攻类型框 |
| `hero_avatar_frame_def.png` | BP / HeroCard 防守类型框 |
| `hero_avatar_frame_econ.png` | BP / HeroCard 经济类型框 |

BattleScreen 的六个头像框均使用 `diamond_mode = true`；本轮让该模式在编辑器中安全预览，因此 BattleScreen 不再显示旧方框，但不会影响上述仍在使用方框素材的界面。

## 其余素材分组

- 光标：`cursor_arrow.png`、`cursor_hand.png`
- 道具与图鉴：`gold_bottom.png`、`item_codex_backdrop.png`、`item_codex_scroll.png`、`item_draft_card.png`、`item_frame.png`
- 图鉴页签与通用 UI：`tab_cloud_t1.png`、`tab_cloud_t2.png`、`tab_cloud_t3.png`、`ui_banner_scroll.png`、`ui_nav_button.png`、`ui_plaque.png`、`ui_tooltip.png`
- 战斗图标：`icons/Bo_idle.png`、`codex_book.png`、`DaBo_idle.png`、`DaFang_idle.png`、`energy_idle.png`、`energy_mote.png`、`Fang_idle.png`、`heart_idle.png`、`Zan_idle.png`

以上均有运行时引用，不列入删除候选。

## 后续若要退役旧方框

应先把 BP、个人资料和技能卡迁移到新的独立头像框组件，再重新扫描并截图验证相关界面。不能只删除 PNG，否则会产生丢失资源或透明空框。
