extends GutTest

const SCENE7_PATH := "res://src/ui/scenes/scene7.tscn"
const BATTLE_SCREEN7_PATH := "res://src/ui/battle_screen7.tscn"
const TORTOISE_SCRIPT_PATH := \
		"res://src/ui/components/scene7_crystal_tortoise.gd"
const BATTLE_SCREEN7_SCRIPT_PATH := "res://src/ui/battle_screen7.gd"


func test_scene7_owns_one_procedural_crystal_tortoise_on_the_platform() -> void:
	assert_true(ResourceLoader.exists(TORTOISE_SCRIPT_PATH))
	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var tortoise := stage.get_node_or_null("CrystalTortoise") as Node2D
	assert_not_null(tortoise)
	if tortoise == null:
		return

	assert_eq((tortoise.get_script() as Script).resource_path,
			TORTOISE_SCRIPT_PATH)
	assert_eq(int(tortoise.call("pose_count")), 3)
	assert_false(bool(tortoise.call("uses_external_texture")))
	assert_true(bool(tortoise.call("uses_authored_pixel_masks")))
	assert_false(bool(tortoise.call("has_bounding_box_glow")))
	assert_false(bool(tortoise.call("has_rectangular_ground_shadow")))
	assert_eq(float(tortoise.get("stop_y_min")), 760.0)
	assert_eq(float(tortoise.get("stop_y_max")), 788.0)
	assert_eq(float(tortoise.call("pixel_grid_size")), 4.0)
	assert_gte(int(tortoise.call("authored_shell_cell_count")), 100)
	assert_gte(int(tortoise.call("authored_body_cell_count")), 50)
	assert_eq(int(tortoise.call("visible_leg_cluster_count")), 4)
	assert_lte((tortoise.call("head_pixel_size") as Vector2).x, 32.0)
	assert_lte((tortoise.call("head_pixel_size") as Vector2).y, 20.0)
	assert_true(bool(tortoise.call("has_shell_contour_glow")))
	assert_gte(int(tortoise.call("contour_glow_cell_count")), 10)
	assert_lte(int(tortoise.call("contour_glow_cell_count")), 24)
	assert_true(bool(tortoise.call("has_stepped_contact_shadow")))
	assert_gte(int(tortoise.call("contact_shadow_cell_count")), 16)
	assert_lte(float(tortoise.call("contact_shadow_height_px")), 12.0)
	assert_gt(float(tortoise.call("glow_peak_alpha")),
			float(tortoise.call("glow_base_alpha")))
	assert_gte((tortoise.call("body_pixel_size") as Vector2).x, 88.0)
	assert_gte((tortoise.call("body_pixel_size") as Vector2).y, 40.0)
	assert_eq(float(tortoise.get_meta("parallax_factor")), 1.0)
	assert_gt(tortoise.get_index(), stage.get_node("BattlePlatform").get_index())
	assert_lt(tortoise.get_index(), stage.get_node("OasisMotesNear").get_index())


func test_completed_resonance_rolls_a_retracted_shell_in_from_offscreen() -> void:
	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var resonance := stage.get_node("OasisResonance")
	var tortoise := stage.get_node("CrystalTortoise")
	tortoise.call("set_random_seed_for_test", 74821)

	_start_visit(resonance)

	assert_true(bool(tortoise.call("is_visit_active")))
	assert_true(bool(tortoise.call("is_rolling_in")))
	assert_false(bool(tortoise.call("is_drinking")))
	assert_eq(int(tortoise.call("visit_count")), 1)
	var start_position := tortoise.call("visual_position") as Vector2
	assert_true(start_position.x < -32.0 or start_position.x > 1952.0,
			"the shell must begin fully outside the 1920px viewport")
	assert_true(tortoise.is_processing())


func test_resonance_visitor_has_a_twenty_percent_spawn_roll() -> void:
	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var resonance := stage.get_node("OasisResonance")
	var tortoise := stage.get_node("CrystalTortoise")
	assert_almost_eq(float(tortoise.get("resonance_visit_probability")),
			0.20, 0.001)
	resonance.call("set_countdown_idle", true)

	tortoise.call("set_next_spawn_roll_for_test", 0.80)
	_register_three_water_zones(resonance)
	assert_false(bool(tortoise.call("is_visit_active")),
			"a completed water sequence must be allowed to miss the true easter egg")
	resonance.call("_finish_resonance")
	tortoise.call("set_next_spawn_roll_for_test", 0.10)
	_register_three_water_zones(resonance)
	assert_true(bool(tortoise.call("is_visit_active")))


func test_successive_visits_randomize_side_and_stop_inside_the_player_gap() -> void:
	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var tortoise := stage.get_node("CrystalTortoise")
	tortoise.call("set_random_seed_for_test", 91357)
	var sides: Array[bool] = []
	var stop_positions: Array[Vector2] = []

	for _visit_index: int in range(3):
		tortoise.call("start_visit")
		sides.append(bool(tortoise.call("entered_from_left")))
		var stop_position := tortoise.call("target_stop_position") as Vector2
		stop_positions.append(stop_position)
		assert_gte(stop_position.x, 800.0)
		assert_lte(stop_position.x, 1120.0)
		assert_gte(stop_position.y, 760.0)
		assert_lte(stop_position.y, 788.0)
		assert_eq(int(stop_position.y) % 4, 0)
		tortoise.call("request_exit", false)
		_process_until_hidden(tortoise)

	assert_true(sides.has(true) and sides.has(false),
			"anti-repeat random entry must expose both sides within three visits")
	assert_gt(absf(stop_positions[0].x - stop_positions[1].x), 48.0)
	assert_gt(absf(stop_positions[1].x - stop_positions[2].x), 48.0)
	assert_true(stop_positions[0].y != stop_positions[1].y \
			or stop_positions[1].y != stop_positions[2].y)


func test_rotating_shell_keeps_its_bottom_on_the_contact_plane() -> void:
	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var tortoise := stage.get_node("CrystalTortoise")
	tortoise.call("set_random_seed_for_test", 27531)
	tortoise.call("start_visit")
	for delta: float in [0.11, 0.13, 0.17, 0.19]:
		tortoise.call("_process", delta)
		assert_almost_eq(float(tortoise.call("rolling_ground_gap_px")),
				0.0, 0.01)


func test_tortoise_stops_between_players_and_looks_both_ways_without_drinking() -> void:
	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var tortoise := stage.get_node("CrystalTortoise")
	tortoise.call("set_random_seed_for_test", 47531)
	tortoise.call("start_visit")
	_process_until_looking(tortoise)

	assert_true(bool(tortoise.call("is_looking")))
	assert_false(bool(tortoise.call("is_drinking")))
	var stopped_position := tortoise.call("visual_position") as Vector2
	assert_almost_eq(stopped_position.x,
			(tortoise.call("target_stop_position") as Vector2).x, 0.01)
	var first_direction := int(tortoise.call("look_direction"))
	tortoise.call("_process", float(tortoise.get("look_interval_sec")) + 0.05)
	assert_ne(int(tortoise.call("look_direction")), first_direction)


func test_attack_interrupt_uses_the_same_rolling_exit_and_never_hides_instantly() -> void:
	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var resonance := stage.get_node("OasisResonance")
	var tortoise := stage.get_node("CrystalTortoise")
	_start_visit(resonance)

	resonance.call("set_countdown_idle", false, true)
	assert_true(bool(tortoise.call("is_visit_active")))
	assert_true(bool(tortoise.call("is_rolling_out")))
	assert_true(bool(tortoise.call("last_exit_was_attack")))
	assert_false(bool(tortoise.call("is_drinking")))

	var exit_duration := float(tortoise.call("current_travel_duration"))
	tortoise.call("_process", exit_duration * 0.5)
	assert_true(bool(tortoise.call("is_visit_active")),
			"attack interruption must play the shared rolling exit")
	tortoise.call("_process", exit_duration * 0.6)
	assert_false(bool(tortoise.call("is_visit_active")))
	assert_eq(int(tortoise.call("completed_exit_count")), 1)


func test_non_attack_countdown_close_uses_the_same_rolling_exit() -> void:
	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var resonance := stage.get_node("OasisResonance")
	var tortoise := stage.get_node("CrystalTortoise")
	_start_visit(resonance)

	resonance.call("set_countdown_idle", false, false)
	assert_true(bool(tortoise.call("is_visit_active")))
	assert_true(bool(tortoise.call("is_rolling_out")))
	assert_false(bool(tortoise.call("last_exit_was_attack")))


func test_battle_screen7_uses_a_scene_local_countdown_adapter() -> void:
	assert_true(ResourceLoader.exists(BATTLE_SCREEN7_SCRIPT_PATH))
	var screen := (load(BATTLE_SCREEN7_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(screen)
	assert_eq((screen.get_script() as Script).resource_path,
			BATTLE_SCREEN7_SCRIPT_PATH)
	assert_true(screen.has_method("_scene7_set_countdown_idle"))
	var screen1 := (load("res://src/ui/battle_screen1.tscn") as PackedScene) \
			.instantiate() as Control
	add_child_autofree(screen1)
	assert_eq((screen1.get_script() as Script).resource_path,
			"res://src/ui/battle_screen.gd")


func test_battle_screen7_committed_attack_starts_the_shared_rolling_exit() -> void:
	var screen := (load(BATTLE_SCREEN7_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(screen)
	var stage := screen.get_node("StageSlot/Stage") as BattleStage
	var resonance := stage.get_node("OasisResonance")
	var tortoise := stage.get_node("CrystalTortoise")
	screen.call("_scene7_set_countdown_idle", true)
	_start_visit(resonance)

	var battle := screen.get("battle") as BattleCore
	assert_not_null(battle)
	if battle == null:
		return
	assert_true(battle.select_action(0, ActionDef.Action.ATTACK))
	assert_true(bool(screen.call("_scene7_any_attack_committed")))
	screen.call("_scene7_set_countdown_idle", false,
			bool(screen.call("_scene7_any_attack_committed")))
	assert_true(bool(tortoise.call("is_rolling_out")))


func test_battle_screen7_detects_the_opponents_committed_attack() -> void:
	var screen := (load(BATTLE_SCREEN7_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(screen)
	var battle := screen.get("battle") as BattleCore
	assert_not_null(battle)
	if battle == null:
		return
	assert_true(battle.select_action(0, ActionDef.Action.CHARGE))
	assert_true(battle.select_action(1, ActionDef.Action.ATTACK))
	assert_true(bool(screen.call("_scene7_any_attack_committed")))


func _start_visit(resonance: Node) -> void:
	resonance.call("set_countdown_idle", true)
	var tortoise := resonance.get_node("../CrystalTortoise")
	tortoise.call("set_next_spawn_roll_for_test", 0.0)
	_register_three_water_zones(resonance)


func _register_three_water_zones(resonance: Node) -> void:
	resonance.call("register_water_click", Vector2(160.0, 710.0))
	resonance.call("register_water_click", Vector2(960.0, 710.0))
	resonance.call("register_water_click", Vector2(1760.0, 710.0))


func _process_until_looking(tortoise: Node) -> void:
	for _step: int in range(60):
		if bool(tortoise.call("is_looking")):
			return
		tortoise.call("_process", 0.05)
	assert_true(false, "tortoise did not reach its looking pose")


func _process_until_hidden(tortoise: Node) -> void:
	for _step: int in range(60):
		if not bool(tortoise.call("is_visit_active")):
			return
		tortoise.call("_process", 0.05)
	assert_true(false, "tortoise did not finish its rolling exit")
