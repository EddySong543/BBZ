extends Node

## h24 并封能量上限换减费界面探针：
## 1) 并封在未出战位时，原本差 1 能的正费用行动仍可选择；
## 2) 选择后自动启用技能分支，并将行动费用预览减少 1；
## 3) 分支使用技能 icon、左上角 -1 上限徽记，并垂直对齐所选行动；
## 4) 行动可正常支付时允许取消分支，取消动作后分支与选择态一并清理。

const ProbeOutput := preload("res://tools/probe_output.gd")
const HERO_DIR := "res://assets/data/heroes/"


func _hero(hero_id: String) -> HeroData:
	return load(HERO_DIR + hero_id + ".tres") as HeroData


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(0, 0)
	BattleSetup.p1_heroes = [_hero("h14"), _hero("h24"), _hero("h05")]
	BattleSetup.p2_heroes = [_hero("h02"), _hero("h08"), _hero("h12")]
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

	var picker: Control = screen.h24_discount_picker
	var branch: Button = screen.btn_h24_discount
	var cap_badge := branch.get_node_or_null("CapCost") as IconBadge
	var branch_icon := branch.get_node_or_null("SkillIcon") as TextureRect
	if picker == null or branch == null:
		failures.append("并封减费分支未创建")
	if picker != null and picker.visible:
		failures.append("未选择行动时并封分支不应显示")
	if cap_badge == null or cap_badge.number != -1:
		failures.append("并封分支左上角缺少 -1 能量上限徽记")
	if branch_icon == null or branch_icon.texture == null:
		failures.append("并封分支内部缺少技能 icon")

	# 仅有 2 能：大波原价 3，只有使用并封减费后才能支付。
	screen.battle.energy[screen.PLAYER] = 4
	screen._refresh_action_affordance()
	if screen.btn_big_attack.disabled:
		failures.append("并封在未出战位时，差 1 能的大波应可选择")
	screen.btn_big_attack.pressed.emit()
	await get_tree().process_frame
	if int(screen.selected_action) != int(ActionDef.Action.BIG_ATTACK):
		failures.append("差 1 能时未能选择大波")
	if not bool(screen._energy_cap_discount_armed):
		failures.append("仅靠并封才能支付时，应自动启用减费")
	if not picker.visible:
		failures.append("选择正费用行动后未显示并封分支")
	var big_badge := screen.btn_big_attack.get_node_or_null("CostPips") as IconBadge
	if big_badge == null or big_badge.number != 2:
		failures.append("并封启用后，大波费用预览应从 3 降为 2")
	if branch.size != screen.btn_big_attack.size:
		failures.append("并封分支应沿用底部行动按钮尺寸")
	if absf(picker.position.x - screen.btn_big_attack.position.x) > 0.5:
		failures.append("并封分支没有与所选行动垂直对齐")

	# 只有借助并封才付得起时，不能取消成必定回退的无效提交。
	branch.pressed.emit()
	await get_tree().process_frame
	if not bool(screen._energy_cap_discount_armed):
		failures.append("行动无法原价支付时不应允许取消并封减费")

	# 能量足够后，玩家可自由在原价 / 降上限减费之间切换。
	screen.battle.energy[screen.PLAYER] = 6
	screen._refresh_action_affordance()
	branch.pressed.emit()
	await get_tree().process_frame
	if bool(screen._energy_cap_discount_armed):
		failures.append("行动可原价支付时应允许取消并封减费")
	if big_badge != null and big_badge.number != 3:
		failures.append("取消并封后，大波费用预览应恢复为 3")
	branch.pressed.emit()
	await get_tree().process_frame
	if not bool(screen._energy_cap_discount_armed):
		failures.append("再次点击分支应重新启用并封减费")

	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProbeOutput.path("h24_energy_cap_discount_selected.png"))

	# 取消已选行动必须同时清掉技能选择和临时分支。
	screen.btn_big_attack.pressed.emit()
	await get_tree().process_frame
	if int(screen.selected_action) != -1:
		failures.append("再次点击大波没有取消行动")
	if bool(screen._energy_cap_discount_armed):
		failures.append("取消行动后并封减费选择没有清理")
	if picker.visible:
		failures.append("取消行动后并封分支没有收起")

	# 龙御极与并封都在队时，两个技能分支应上下堆叠，不覆盖彼此或底部「波」。
	screen.battle.energy[screen.PLAYER] = 6
	screen.btn_attack.pressed.emit()
	await get_tree().process_frame
	var longyuji_picker: Control = screen.longyuji_picker
	if not longyuji_picker.visible or not picker.visible:
		failures.append("选择波后，龙御极与并封分支应同时显示")
	elif picker.position.y + picker.size.y + 13.0 > longyuji_picker.position.y:
		failures.append("并封分支应堆叠在龙御极上方，不得互相覆盖")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProbeOutput.path("h24_h05_stacked_branches.png"))

	# 蚩尤与并封叠加后，若行动已无法改回能量支付，关闭天不葬必须被阻止。
	screen.btn_attack.pressed.emit()
	await get_tree().process_frame
	screen.battle.energy[screen.PLAYER] = 0
	screen.btn_special.pressed.emit()
	await get_tree().process_frame
	if not bool(screen._blood_payment_armed):
		failures.append("蚩尤出战时应能开启生命支付")
	screen.btn_big_attack.pressed.emit()
	await get_tree().process_frame
	if not picker.visible:
		failures.append("生命支付选中大波后仍应显示并封分支")
	branch.pressed.emit()
	await get_tree().process_frame
	if not bool(screen._energy_cap_discount_armed):
		failures.append("并封应能先降低大波费用，再交由蚩尤支付生命")
	screen.btn_special.pressed.emit()
	await get_tree().process_frame
	if not bool(screen._blood_payment_armed):
		failures.append("0 能量时已选大波只能靠蚩尤支付，不应允许直接关闭技能")

	if failures.is_empty():
		print("H24_ENERGY_CAP_DISCOUNT_PROBE_PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("H24_ENERGY_CAP_DISCOUNT_PROBE: " + failure)
		get_tree().quit(1)
