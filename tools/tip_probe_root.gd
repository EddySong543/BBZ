extends Node

## 悬停提示+3选1 描述换行探针（作为主场景跑 → 正常加载 autoload）：
##   godot --path . res://tools/tip_probe.tscn
## 状态注入式（⚠warp_mouse 会被物理鼠标覆盖·见 godot-ui-render-quirks）：
##   直接调 battle_screen 的提示函数 → S/L 固定尺寸、长文换行与3选1最长描述回归图。
## 输出：统一探针目录（默认 user://probe-output，可由命令行覆盖）。

const ProbeOutput := preload("res://tools/probe_output.gd")
const DraftPopup := preload("res://src/ui/components/item_draft_popup.gd")


func _ready() -> void:
	var s: Node = load("res://src/ui/battle_screen1.tscn").instantiate()
	add_child(s)
	await get_tree().create_timer(2.2).timeout
	# ① 攒按钮提示
	s._on_tip_enter(s.btn_charge, s._action_tip.bind(ActionDef.Action.CHARGE), s.TipFormat.S, true)
	await RenderingServer.frame_post_draw
	print("tip-size:S=", s._tip_panel.size)
	get_viewport().get_texture().get_image().save_png(ProbeOutput.path("tip_btn.png"))
	print("saved: tip_btn.png")
	# ② 大防为 S 框最长基础文案：必须完整换行，不得撑框或裁切。
	s._on_tip_enter(s.btn_big_defend, s._action_tip.bind(ActionDef.Action.BIG_DEFEND),
		s.TipFormat.S, true)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProbeOutput.path("tip_big_defend.png"))
	print("saved: tip_big_defend.png size=", s._tip_panel.size)
	# ③ 主动技能必须使用 L 框和技能正文排版。
	s._on_tip_enter(s.btn_special, s._special_tip, s.TipFormat.L, false,
		s.TipContentKind.SKILL)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProbeOutput.path("tip_active_skill.png"))
	print("saved: tip_active_skill.png size=", s._tip_panel.size)
	# ④ 技能延伸按钮同样使用 L 框与居中技能排版。
	s._show_tip_at(s.btn_longyuji_branch.get_global_rect(), s._longyuji_tip(),
		s.TipFormat.L, false, s.TipContentKind.SKILL)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProbeOutput.path("tip_skill_branch.png"))
	print("saved: tip_skill_branch.png size=", s._tip_panel.size)
	# ⑤ 道具槽 0 提示。
	s._on_item_slot_hovered(0)
	await RenderingServer.frame_post_draw
	print("tip-size:L=", s._tip_panel.size)
	get_viewport().get_texture().get_image().save_png(ProbeOutput.path("tip_slot.png"))
	print("saved: tip_slot.png")
	s._hide_tip()
	# ⑥ 3选1 弹窗 = 全目录描述最长的 3 件（验换行不溢出）
	var pool: Array[ItemData] = ItemCatalog.all()
	pool.sort_custom(func(a: ItemData, b: ItemData) -> bool: return a.description.length() > b.description.length())
	var popup: Control = DraftPopup.new()
	add_child(popup)
	popup.setup([pool[0], pool[1], pool[2]], true, "换行探针（最长描述×3）")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProbeOutput.path("tip_draft.png"))
	print("saved: tip_draft.png")
	get_tree().quit()
