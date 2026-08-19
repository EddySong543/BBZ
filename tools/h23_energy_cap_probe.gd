extends Node

## h23 动态能量上限 HUD 探针：默认上限不添常驻噪音，受损后只显示一行小型持久提示。

const ProbeOutput := preload("res://tools/probe_output.gd")
const HERO_DIR := "res://assets/data/heroes/"


func _hero(hero_id: String) -> HeroData:
	return load(HERO_DIR + hero_id + ".tres") as HeroData


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i.ZERO
	BattleSetup.p1_heroes = [_hero("h23"), _hero("h05"), _hero("h02")]
	BattleSetup.p2_heroes = [_hero("h24"), _hero("h08"), _hero("h12")]
	BattleSetup.overtime = false
	BattleSetup.pve_mode = false
	BattleSetup.story_mode = false
	BattleSetup.net_session = null

	var screen: Node = load("res://src/ui/battle_screen1.tscn").instantiate()
	add_child(screen)
	await get_tree().create_timer(2.2).timeout
	screen.battle.energy.assign([20, 20])
	screen.battle.energy_max.assign([20, 17])
	screen._update_energy_labels()
	await RenderingServer.frame_post_draw

	var failures: Array[String] = []
	if screen.p1_energy_cap_label.visible:
		failures.append("默认上限一侧不应显示额外标签")
	if not screen.p2_energy_cap_label.visible:
		failures.append("受损上限一侧未显示标签")
	if screen.p2_energy_cap_label.text != "能量上限 8.5":
		failures.append("动态上限文案或半能换算错误")

	var output_path := ProbeOutput.path("h23_energy_cap_hud.png")
	var save_error := get_viewport().get_texture().get_image().save_png(output_path)
	if save_error != OK:
		failures.append("截图保存失败: %s" % error_string(save_error))

	if failures.is_empty():
		print("H23_ENERGY_CAP_PROBE_PASS: ", output_path)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("H23_ENERGY_CAP_PROBE: " + failure)
		get_tree().quit(1)
