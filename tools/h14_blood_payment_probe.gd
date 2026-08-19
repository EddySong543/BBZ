extends Node

## h14 蚩尤生命支付界面探针：
## 1) 0 能量时付费动作默认禁用；
## 2) 点击技能后仍可继续选择动作，付费动作改用心形费用图标并恢复可点；
## 3) 经 h07 本回合唯一一次免费切换后，原蚩尤仍是付款者，星日可继续选择付费动作。

const ProbeOutput := preload("res://tools/probe_output.gd")
const HERO_DIR := "res://assets/data/heroes/"


func _hero(hero_id: String) -> HeroData:
	return load(HERO_DIR + hero_id + ".tres") as HeroData


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(0, 0)
	BattleSetup.p1_heroes = [_hero("h14"), _hero("h07"), _hero("h17")]
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

	screen.battle.energy[screen.PLAYER] = 0
	screen._refresh_action_affordance()
	if not screen.btn_attack.disabled or not screen.btn_big_attack.disabled:
		failures.append("0 能量且未开启技能时，波与大波应禁用")
	if not screen.btn_special.visible or screen.btn_special.disabled:
		failures.append("蚩尤出战时技能按钮应显示且可点")

	screen.btn_special.pressed.emit()
	await get_tree().process_frame
	if not bool(screen._blood_payment_armed):
		failures.append("点击技能后未进入生命支付状态")
	if screen.btn_special.modulate == Color.WHITE:
		failures.append("技能按钮缺少选中反馈")
	if screen.btn_attack.disabled or screen.btn_big_attack.disabled or screen.btn_big_defend.disabled:
		failures.append("生命足够时，付费动作应恢复可点")

	for btn: Button in [screen.btn_attack, screen.btn_big_attack, screen.btn_big_defend]:
		var badge: IconBadge = btn.get_node_or_null("CostPips") as IconBadge
		if badge == null or badge.sheet == null \
				or not badge.sheet.resource_path.ends_with("heart_idle.png"):
			failures.append("%s 未切换为生命费用图标" % btn.name)

	var h07_frame: int = screen.p1_frame_slots.find(1)
	screen._free_switch_now(h07_frame)
	await get_tree().process_frame
	if not bool(screen._blood_payment_armed):
		failures.append("免费切到星日后不应取消已开启的血量支付")
	if screen.battle.is_free_switch_target(screen.PLAYER, 2):
		failures.append("千里自在风同回合不应允许第二次免费切换")
	if int(screen.battle.blood_payment_source(screen.PLAYER)) != 0:
		failures.append("免费切换后付款者没有保留为原槽蚩尤")
	if not bool(screen._blood_payment_armed):
		failures.append("一次免费切换不应取消血量支付")
	var big_badge: IconBadge = screen.btn_big_attack.get_node_or_null("CostPips") as IconBadge
	if big_badge == null or big_badge.sheet == null \
			or not big_badge.sheet.resource_path.ends_with("heart_idle.png"):
		failures.append("星日大波费用未切换为生命图标")
	screen.btn_big_attack.pressed.emit()
	await get_tree().process_frame
	if int(screen.selected_action) != int(ActionDef.Action.BIG_ATTACK):
		failures.append("血量支付开启后未能选择星日大波")
	if not bool(screen._blood_payment_armed):
		failures.append("选择星日大波不应取消血量支付")

	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProbeOutput.path("h14_blood_payment_selected.png"))

	if failures.is_empty():
		print("H14_BLOOD_PAYMENT_PROBE_PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("H14_BLOOD_PAYMENT_PROBE: " + failure)
		get_tree().quit(1)
