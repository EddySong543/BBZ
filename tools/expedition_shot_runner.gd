extends Node

## 远征模式界面截图 runner（实装自检用·完整引擎模式跑→autoload 可用）：
##   godot --path . res://tools/expedition_shot_runner.tscn
## 覆盖（2026-07-07 全屏地图形态）：选英雄浮层 → 进图 idle → 走动（迷雾扩张）→ B 背包浮层（含注入物品）
## → 弹窗样式 → 死亡链路回归（L 任务重建·走【饥饿死】路径：不碰"进战"真战斗转场·途中弹窗直接 hide 跳过）。
## 战斗路径回归另走 tools/pve_battle_shot_runner。

const HeroDataScript := preload("res://src/battle/hero_data.gd")

const OUT_SELECT := "D:/Game/BoBoZan/exped_select.png"
const OUT_IDLE := "D:/Game/BoBoZan/exped_idle.png"
const OUT_WALK := "D:/Game/BoBoZan/exped_walk.png"
const OUT_BACKPACK := "D:/Game/BoBoZan/exped_backpack.png"
const OUT_DIALOG := "D:/Game/BoBoZan/exped_dialog.png"
const OUT_DEATH := "D:/Game/BoBoZan/exped_death.png"

const WALK_KEYS: Array = [KEY_D, KEY_D, KEY_S, KEY_D, KEY_D, KEY_S, KEY_D, KEY_W, KEY_D, KEY_D]


func _ready() -> void:
	# 本机窗口可能被开成小于 1920（屏幕适配）→ 1920 设计坐标被裁。强制 canvas_items 缩放
	# 让整个 1080p 设计缩进实际窗口（只影响 runner 截图·不动 project.godot）。
	var w := get_window()
	w.content_scale_size = Vector2i(1920, 1080)
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var screen := (load("res://src/expedition/expedition_screen.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().create_timer(0.5).timeout
	await _shot(OUT_SELECT)
	# 代码选定初始英雄（取池中第 3 个=有立绘的常规英雄）→ 进图
	screen._on_hero_selected(HeroDataScript.create_launch_pool()[2])
	await get_tree().create_timer(0.6).timeout
	await _shot(OUT_IDLE)
	for k: int in WALK_KEYS:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.physical_keycode = k
		ev.pressed = true
		Input.parse_input_event(ev)
		await get_tree().create_timer(0.12).timeout
	await get_tree().create_timer(0.4).timeout
	await _shot(OUT_WALK)
	# —— 背包浮层验证：注入掉落 → B 浮层（拾取区图标 + 背包放置 + 保险槽）——
	var loot_script := preload("res://src/expedition/expedition_loot.gd")
	screen.pending.append_array(loot_script.roll_drop(screen.map.rng, "t3"))
	screen.pending.append_array(loot_script.roll_drop(screen.map.rng, "chest"))
	screen.bp.place(loot_script.make_gold(screen.map.rng), loot_script.SHAPE_1X1, Vector2i(0, 0))
	var urn_item: Dictionary = {"id": "urn", "name": "古瓮", "cat": "gold", "tier": 0, "shape": loot_script.SHAPE_2X2, "gold": 120, "note": "120金", "icon": "urn"}
	screen.bp.place(urn_item, loot_script.SHAPE_2X2, Vector2i(1, 1))
	screen.bp.insure(loot_script.make_consumable(screen.map.rng))
	screen._toggle_backpack(true)
	await get_tree().create_timer(0.3).timeout
	await _shot(OUT_BACKPACK)
	print("背包浮层可见=", screen.bp_overlay.visible, "  地图弹窗可见=", screen.dialog.visible)
	# —— 弹窗样式验证（D 任务·暖骨底+jelly 按钮）——
	screen._toggle_backpack(false)
	if not screen.dialog.visible:
		screen._prompt_leave()
	await get_tree().create_timer(0.4).timeout
	await _shot(OUT_DIALOG)
	# —— 死亡链路回归（Eddy 踩坑双病根的守门员·L 任务重建）：饥饿死 → 结算弹窗必须弹出且无旧按钮残留 ——
	screen.dialog.hide()                # 关掉当前任意弹窗（直接 hide 不触发回调·安全）
	screen.map.supplies = 0
	for h: Dictionary in screen.map.team:
		h["hp"] = 0.5                   # 残血：下一次饥饿行军（-0.5）即全灭
	for i: int in 30:
		if screen.map.over:
			break
		if screen.dialog.visible:
			screen.dialog.hide()        # 途中遭遇/撤离弹窗一律跳过继续走
			await get_tree().create_timer(0.05).timeout
		var ev2 := InputEventKey.new()
		ev2.keycode = [KEY_D, KEY_S, KEY_A, KEY_W][i % 4]
		ev2.physical_keycode = ev2.keycode
		ev2.pressed = true
		Input.parse_input_event(ev2)
		await get_tree().create_timer(0.08).timeout
	await get_tree().create_timer(0.5).timeout
	var kids: int = screen.dialog_box.get_child_count()
	print("死亡回归：局已结束=", screen.map.over, "  结算弹窗可见=", screen.dialog.visible,
		"  弹窗子节点=", kids, "（应为 3：文案+2按钮·>3=旧按钮残留 bug 复发）")
	await _shot(OUT_DEATH)
	get_tree().quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved: ", path)
