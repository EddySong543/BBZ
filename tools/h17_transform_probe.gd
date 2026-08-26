extends Node

## h17 烛阴转变界面探针：
## 真实运行战斗界面，发动主动技后校验战斗数据、立绘、头像、血条、技能按钮与技能情报同步刷新。

const ProbeOutput := preload("res://tools/probe_output.gd")
const HERO_DIR := "res://assets/data/heroes/"


func _hero(hero_id: String) -> HeroData:
	return load(HERO_DIR + hero_id + ".tres") as HeroData


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(0, 0)
	BattleSetup.p1_heroes = [_hero("h17"), _hero("h02"), _hero("h08")]
	BattleSetup.p2_heroes = [_hero("h15"), _hero("h10"), _hero("h12")]
	BattleSetup.overtime = false
	BattleSetup.pve_mode = false
	BattleSetup.net_session = null

	var screen: Node = load("res://src/ui/battle_screen1.tscn").instantiate()
	add_child(screen)
	await get_tree().create_timer(2.2).timeout
	var failures: Array[String] = []
	if int(screen.state) != int(screen.State.PLAYER_SELECT):
		failures.append("战斗界面未进入选招阶段")

	screen.battle.energy[screen.PLAYER] = 4
	screen.battle.hp[screen.AI][0] = 9
	screen.battle.shield[screen.AI][0] = 3
	screen.battle.set_status(screen.AI, 0, "vuln", 1)
	screen._update_all()
	if not screen.btn_special.visible or screen.btn_special.disabled:
		failures.append("烛阴在2点能量时技能按钮应显示且可用")
	if int(screen.battle.action_cost(screen.PLAYER, ActionDef.ACTIVE)) != 4:
		failures.append("烛阴主动技费用应为2点能量")

	screen.btn_special.pressed.emit()
	await get_tree().process_frame
	if int(screen.selected_action) != int(ActionDef.ACTIVE):
		failures.append("点击技能后未选中主动技")
	if not screen.battle.select_active(screen.PLAYER):
		failures.append("战斗核心未能提交烛阴主动技")
	screen.battle.select_action(screen.AI, ActionDef.Action.CHARGE)
	await screen._resolve()
	await get_tree().create_timer(0.3).timeout

	var transformed := screen.battle.heroes[screen.PLAYER][0] as HeroData
	if transformed.hero_id != "h15":
		failures.append("战斗数据未转变为敌方当前出战的穷奇")
	if int(screen.battle.hp[screen.PLAYER][0]) != 9:
		failures.append("当前生命未复制为敌方的4.5点")
	if int(screen.battle.max_hp[screen.PLAYER][0]) != 14:
		failures.append("生命上限未复制为穷奇的7点")
	if int(screen.battle.shield[screen.PLAYER][0]) != 3:
		failures.append("护甲未随英雄本体状态复制")
	if int(screen.battle.get_status(screen.PLAYER, 0, "vuln", 0)) != 1:
		failures.append("英雄局部状态未复制")
	if int(screen.battle.energy[screen.PLAYER]) != 2:
		failures.append("团队能量应只扣2点并获得回合被动1点，不应复制敌方能量")
	if screen.p1_active_name.text != transformed.hero_name:
		failures.append("出战英雄名未刷新为穷奇")
	if screen.p1_frames[0].hero_name != transformed.hero_name:
		failures.append("出战头像框未刷新为穷奇")
	if String(screen.p1_char_display.sprite_frames_path) != transformed.sprite_frames_path:
		failures.append("中央立绘未刷新为穷奇")
	if screen.btn_special.visible:
		failures.append("转变为被动英雄后，主动技能按钮应隐藏")
	var info_hero := screen._skill_info._hero(screen.PLAYER) as HeroData
	if info_hero == null or info_hero.hero_id != "h15":
		failures.append("技能情报按钮未跟随转变后的英雄")

	await RenderingServer.frame_post_draw
	var screenshot_path := ProbeOutput.path("h17_transformed_to_h15.png")
	var save_error := get_viewport().get_texture().get_image().save_png(screenshot_path)
	if save_error != OK:
		failures.append("截图保存失败：%s" % error_string(save_error))
	else:
		print("saved: ", screenshot_path)

	if failures.is_empty():
		print("H17_TRANSFORM_PROBE_PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("H17_TRANSFORM_PROBE: " + failure)
		get_tree().quit(1)
