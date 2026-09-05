extends Node

## h05 龙御极单分支探针：
## 1) 未选择「波」时不显示分支；
## 2) 选择「波」后，在正上方追加一个带技能 icon 与 1 能角标的分支；
## 3) 「波」保留基础 1 能，技能分支表示额外 1 能；
## 4) 再次点击技能分支可退回普通波，取消「波」后分支立即收起。

const ProbeOutput := preload("res://tools/probe_output.gd")
const HERO_DIR := "res://assets/data/heroes/"


func _hero(hero_id: String) -> HeroData:
	return load(HERO_DIR + hero_id + ".tres") as HeroData


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(0, 0)
	BattleSetup.p1_heroes = [_hero("h05"), _hero("h10"), _hero("h01")]
	BattleSetup.p2_heroes = [_hero("h02"), _hero("h08"), _hero("h12")]
	BattleSetup.overtime = false
	BattleSetup.pve_mode = false

	var screen: Node = load("res://src/ui/battle_screen1.tscn").instantiate()
	add_child(screen)
	await get_tree().create_timer(2.2).timeout
	var failures: Array[String] = []
	var attack_button: Button = screen.btn_attack
	var picker: Control = screen.longyuji_picker
	var branch_button: Button = screen.btn_longyuji_branch
	var wave_cost_badge := attack_button.get_node_or_null("CostPips") as IconBadge
	var branch_cost_badge := branch_button.get_node_or_null("CostPips") as IconBadge
	var branch_icon := branch_button.get_node_or_null("SkillIcon") as TextureRect
	if int(screen.state) != int(screen.State.PLAYER_SELECT):
		failures.append("战斗界面未进入选招阶段")
	if picker == null or branch_button == null:
		failures.append("龙御极临时分支未创建")
	if picker != null and picker.visible:
		failures.append("未选择波时分支不应显示")
	if wave_cost_badge == null:
		failures.append("波按钮缺少费用徽记")
	if branch_cost_badge == null or branch_cost_badge.number != 1:
		failures.append("龙御极分支左上角缺少额外1能徽记")
	if branch_icon == null or branch_icon.texture == null:
		failures.append("龙御极分支内部缺少技能icon")

	screen.battle.energy[screen.PLAYER] = 8
	screen._refresh_action_affordance()
	attack_button.pressed.emit()
	await get_tree().process_frame
	if int(screen.selected_action) != int(ActionDef.Action.ATTACK):
		failures.append("点击波没有选择普通波")
	if not picker.visible:
		failures.append("选择波后没有显示龙御极分支")
	if bool(screen._empowered_wave_armed):
		failures.append("展开分支时默认应为普通波")
	if wave_cost_badge != null and wave_cost_badge.number != 1:
		failures.append("普通波选中时费用应为1")
	if branch_button.size != attack_button.size:
		failures.append("龙御极分支应沿用底部动作按钮尺寸")
	if absf(picker.position.x - attack_button.position.x) > 0.5:
		failures.append("龙御极分支没有与波按钮垂直对齐")

	branch_button.pressed.emit()
	await get_tree().process_frame
	if not bool(screen._empowered_wave_armed):
		failures.append("点击龙御极分支后未进入强化状态")
	if wave_cost_badge != null and wave_cost_badge.number != 1:
		failures.append("强化时波按钮仍应只显示基础1能")
	if branch_cost_badge != null and branch_cost_badge.number != 1:
		failures.append("强化时龙御极分支应显示额外1能")
	if String(screen._action_tip(ActionDef.Action.ATTACK)) != "造成1点伤害，可被「防」、「大防」抵挡":
		failures.append("波提示应只保留固定功能说明")
	if String(screen._longyuji_tip()) != "使「波」额外造成1点伤害":
		failures.append("龙御极分支提示应只说明强化功能")
	branch_button.mouse_entered.emit()
	await get_tree().process_frame
	if not screen._tip_panel.visible or screen._tip_panel.size != screen.tip_size_s:
		failures.append("龙御极分支未使用固定 S 说明框")

	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProbeOutput.path("h05_longyuji_branch_picker.png"))

	branch_button.pressed.emit()
	await get_tree().process_frame
	if bool(screen._empowered_wave_armed):
		failures.append("再次点击龙御极分支后没有退回普通波")

	attack_button.pressed.emit()
	await get_tree().process_frame
	if int(screen.selected_action) != -1:
		failures.append("再次点击波没有沿用既有取消选择行为")
	if picker.visible:
		failures.append("取消波后临时双选菜单没有收起")

	if failures.is_empty():
		print("H05_LONGYUJI_BRANCH_PICKER_PROBE_PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("H05_LONGYUJI_BRANCH_PICKER_PROBE: " + failure)
		get_tree().quit(1)
