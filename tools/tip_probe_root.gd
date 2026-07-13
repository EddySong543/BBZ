extends Node

## 悬停提示+3选1 描述换行探针（作为主场景跑 → 正常加载 autoload）：
##   godot --path . res://tools/tip_probe.tscn
## 状态注入式（⚠warp_mouse 会被物理鼠标覆盖·见 godot-ui-render-quirks）：
##   直接调 battle_screen 的提示函数 → 三截图：①攒按钮提示 ②道具槽提示 ③3选1 最长描述卡。
## 输出到 session scratchpad（不落仓库目录）。

const OUT_DIR := "C:/Users/Edzzz/AppData/Local/Temp/claude/D--Game-BoBoZan-Claude-Code-Game-Studios-cn-localization/d876abac-d136-4bc5-969a-26bb80fa7d86/scratchpad/"
const DraftPopup := preload("res://src/ui/components/item_draft_popup.gd")


func _ready() -> void:
	var s: Node = load("res://src/ui/battle_screen.tscn").instantiate()
	add_child(s)
	await get_tree().create_timer(2.2).timeout
	# ① 攒按钮提示
	s._on_tip_enter(s.btn_charge, s._action_tip.bind(ActionDef.Action.CHARGE))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_DIR + "tip_btn.png")
	print("saved: tip_btn.png")
	# ② 道具槽 0 提示（回合 1 = 未解锁态）
	s._on_item_slot_hovered(0)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_DIR + "tip_slot.png")
	print("saved: tip_slot.png")
	s._hide_tip()
	# ③ 3选1 弹窗 = 全目录描述最长的 3 件（验换行不溢出）
	var pool: Array[ItemData] = ItemCatalog.all()
	pool.sort_custom(func(a: ItemData, b: ItemData) -> bool: return a.description.length() > b.description.length())
	var popup: Control = DraftPopup.new()
	add_child(popup)
	popup.setup([pool[0], pool[1], pool[2]], true, "换行探针（最长描述×3）")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_DIR + "tip_draft.png")
	print("saved: tip_draft.png")
	get_tree().quit()
