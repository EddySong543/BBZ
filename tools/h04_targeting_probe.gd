extends Node

## h04【十方无次第】界面输入探针：
## 1) 选「波」后，三个存活敌方头像均进入目标态且默认锁定出战位；
## 2) 点击替补头像后，目标切到对应英雄；
## 3) 替补受击与格挡反馈只落在该头像框，不改中央角色显示。

const ProbeOutput := preload("res://tools/probe_output.gd")
const HERO_DIR := "res://assets/data/heroes/"


func _hero(hero_id: String) -> HeroData:
	return load(HERO_DIR + hero_id + ".tres") as HeroData


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProbeOutput.path(file_name))


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(0, 0)
	BattleSetup.p1_heroes = [_hero("h04"), _hero("h01"), _hero("h02")]
	BattleSetup.p2_heroes = [_hero("h03"), _hero("h05"), _hero("h06")]
	BattleSetup.overtime = false
	BattleSetup.pve_mode = false
	BattleSetup.story_mode = false
	BattleSetup.net_session = null

	var screen: Node = load("res://src/ui/battle_screen1.tscn").instantiate()
	add_child(screen)
	await get_tree().create_timer(2.2).timeout
	var failures: Array[String] = []
	if int(screen.state) != int(screen.State.PLAYER_SELECT):
		failures.append("战斗界面未进入选招阶段")

	screen.btn_attack.pressed.emit()
	await get_tree().process_frame
	if not bool(screen._enemy_targeting):
		failures.append("选择波后未进入敌方目标态")
	if int(screen._enemy_target_pick) != int(screen.battle.active_index[screen.AI]):
		failures.append("选择波后没有默认锁定敌方出战位")
	for frame_idx in [0, 1, 2]:
		var prompt := screen.p2_frames[frame_idx].get_node_or_null("SwitchPrompt") as Label
		if prompt == null or not prompt.visible or prompt.text != "攻":
			failures.append("敌方头像 %d 未显示可攻击提示" % frame_idx)
	await _shot("h04_targeting_default.png")

	var target_slot: int = int(screen.p2_frame_slots[1])
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	screen._on_enemy_frame_input(click, 1)
	await get_tree().process_frame
	if int(screen._enemy_target_pick) != target_slot:
		failures.append("点击敌方替补头像后目标槽未更新")
	if not bool(screen.p2_frames[1].is_selected):
		failures.append("点击的敌方替补头像没有选中反馈")
	await _shot("h04_targeting_reserve_selected.png")

	var central_modulate: Color = screen.p2_char_display.modulate
	screen._clear_enemy_targets()
	screen._impact_reserve_slot(screen.AI, target_slot, 2, ActionDef.Pen.NORMAL)
	await get_tree().create_timer(0.1).timeout
	if screen.p2_frames[1].get_node_or_null("ReserveDamage") == null:
		failures.append("替补受击时没有在对应头像生成伤害数字")
	if screen.p2_char_display.modulate != central_modulate:
		failures.append("替补受击错误改变了中央角色显示")
	await _shot("h04_targeting_reserve_hit.png")
	await get_tree().create_timer(0.5).timeout

	screen._impact_reserve_slot(screen.AI, target_slot, 0, ActionDef.Pen.NORMAL, true, true)
	await get_tree().create_timer(0.1).timeout
	if screen.p2_frames[1].get_node_or_null("ReserveBlock") == null:
		failures.append("替补格挡时没有在对应头像生成格挡反馈")
	if screen.p2_char_display.modulate != central_modulate:
		failures.append("替补格挡错误改变了中央角色显示")
	await _shot("h04_targeting_reserve_block.png")

	if failures.is_empty():
		print("H04_TARGETING_PROBE_PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("H04_TARGETING_PROBE: " + failure)
		get_tree().quit(1)
