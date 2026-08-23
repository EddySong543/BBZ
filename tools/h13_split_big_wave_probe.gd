extends Node

## h13 玄冥双波界面探针：
## 1) 玄冥出战并选择「大波」后，在「大波」正上方显示暗潮技能 icon 分支；
## 2) 点击后进入选中态，并把待提交动作标记为双波。

const ProbeOutput := preload("res://tools/probe_output.gd")
const HERO_DIR := "res://assets/data/heroes/"


func _hero(hero_id: String) -> HeroData:
	return load(HERO_DIR + hero_id + ".tres") as HeroData


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(0, 0)
	BattleSetup.p1_heroes = [_hero("h13"), _hero("h10"), _hero("h05")]
	BattleSetup.p2_heroes = [_hero("h02"), _hero("h08"), _hero("h12")]
	BattleSetup.overtime = false
	BattleSetup.pve_mode = false
	BattleSetup.net_session = null

	var screen: Node = load("res://src/ui/battle_screen1.tscn").instantiate()
	add_child(screen)
	await get_tree().create_timer(2.2).timeout
	var failures: Array[String] = []
	var big_wave_button: Button = screen.btn_big_attack
	var picker: Control = screen.split_big_wave_picker
	var branch_button: Button = screen.btn_split_big_wave
	var branch_icon := branch_button.get_node_or_null("SkillIcon") as TextureRect
	if int(screen.state) != int(screen.State.PLAYER_SELECT):
		failures.append("战斗界面未进入选招阶段")
	if picker == null or branch_button == null:
		failures.append("暗潮临时分支未创建")
	if picker != null and picker.visible:
		failures.append("未选择大波时暗潮分支不应显示")
	if branch_icon == null or branch_icon.texture == null:
		failures.append("暗潮分支内部缺少技能icon")

	screen.battle.energy[screen.PLAYER] = 8
	screen._refresh_action_affordance()
	big_wave_button.pressed.emit()
	await get_tree().process_frame
	if not picker.visible:
		failures.append("玄冥选择大波后未显示攻击变体按钮")
	if branch_button.disabled:
		failures.append("玄冥有足够能量时暗潮分支不应禁用")
	if branch_button.text != "":
		failures.append("暗潮分支应只显示技能icon，不再使用文字按钮")
	if branch_button.size != big_wave_button.size:
		failures.append("暗潮分支应沿用大波按钮尺寸")
	if absf(picker.position.x - big_wave_button.position.x) > 0.5:
		failures.append("暗潮分支没有与大波按钮垂直对齐")
	if picker.position.y >= big_wave_button.position.y:
		failures.append("暗潮分支没有放在大波按钮上方")
	if branch_button.get_node_or_null("CostPips") != null:
		failures.append("暗潮不额外耗能，不应显示额外能量角标")

	branch_button.pressed.emit()
	await get_tree().process_frame
	if not bool(screen._split_big_wave_armed):
		failures.append("点击暗潮分支后未进入待提交状态")
	if branch_button.modulate == Color.WHITE:
		failures.append("暗潮分支缺少选中反馈")

	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProbeOutput.path("h13_split_big_wave_selected.png"))

	if failures.is_empty():
		print("H13_SPLIT_BIG_WAVE_PROBE_PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("H13_SPLIT_BIG_WAVE_PROBE: " + failure)
		get_tree().quit(1)
