extends GutTest

const SCENE7_PATH := "res://src/ui/scenes/scene7.tscn"


func test_three_distinct_water_zones_start_one_visible_resonance() -> void:
	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var resonance := stage.get_node_or_null("OasisResonance")
	assert_not_null(resonance)
	if resonance == null:
		return
	resonance.call("set_countdown_idle", true)

	assert_true(bool(resonance.call("register_water_click", Vector2(160.0, 710.0))))
	assert_false(bool(resonance.call("register_water_click", Vector2(420.0, 710.0))))
	assert_eq(int(resonance.call("registered_zone_count")), 1)
	assert_true(bool(resonance.call("register_water_click", Vector2(960.0, 710.0))))
	assert_true(bool(resonance.call("register_water_click", Vector2(1760.0, 710.0))))

	assert_eq(int(resonance.call("resonance_count")), 1)
	assert_true(bool(resonance.call("is_resonating")))
	assert_gt(int(resonance.call("active_pulse_count")), 0)
	assert_gt(int(resonance.call("particle_count")), 0)


func test_partial_sequence_expires_instead_of_triggering_late() -> void:
	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var resonance := stage.get_node_or_null("OasisResonance")
	assert_not_null(resonance)
	if resonance == null:
		return
	resonance.call("set_countdown_idle", true)

	resonance.call("register_water_click", Vector2(160.0, 710.0))
	resonance.call("_process", float(resonance.get("trigger_window_sec")) + 0.01)
	assert_eq(int(resonance.call("registered_zone_count")), 0)
	assert_true(bool(resonance.call("register_water_click", Vector2(960.0, 710.0))))
	assert_true(bool(resonance.call("register_water_click", Vector2(1760.0, 710.0))))
	assert_eq(int(resonance.call("resonance_count")), 0)


func test_water_ripple_signals_feed_the_scene7_local_controller() -> void:
	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var resonance := stage.get_node_or_null("OasisResonance")
	var rear := stage.get_node("RearSpringClickRipple") as Control
	assert_not_null(resonance)
	if resonance == null:
		return
	resonance.call("set_countdown_idle", true)

	rear.emit_signal("effect_spawned", 1, Vector2(160.0, 710.0))
	rear.emit_signal("effect_spawned", 1, Vector2(960.0, 710.0))
	rear.emit_signal("effect_spawned", 1, Vector2(1760.0, 710.0))
	assert_eq(int(resonance.call("resonance_count")), 1)


func test_resonance_controller_is_passive_and_has_three_authored_glow_groups() -> void:
	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var resonance := stage.get_node_or_null("OasisResonance") as Node2D
	assert_not_null(resonance)
	if resonance == null:
		return

	assert_eq(resonance.get("glow_group_paths").size(), 3)
	assert_eq(resonance.get("particle_origins").size(), 3)
	assert_false(resonance.has_method("_input"))
	assert_false(resonance.has_method("_unhandled_input"))
	assert_almost_eq(float(resonance.get_meta("parallax_factor")), 1.0, 0.001)


func test_relay_has_an_obvious_peak_and_restores_the_authored_palette() -> void:
	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var resonance := stage.get_node_or_null("OasisResonance")
	var left_glow := stage.get_node("MidgroundLeftGlowFX") as CanvasItem
	var center_glow := stage.get_node("MidgroundCenterGlowFX") as CanvasItem
	assert_not_null(resonance)
	if resonance == null:
		return
	resonance.call("set_countdown_idle", true)
	var left_base := left_glow.modulate
	var center_base := center_glow.modulate

	resonance.call("register_water_click", Vector2(160.0, 710.0))
	resonance.call("register_water_click", Vector2(960.0, 710.0))
	resonance.call("register_water_click", Vector2(1760.0, 710.0))
	resonance.call("_process", float(resonance.get("sequence_lead_in_sec")) + 0.01)

	assert_gt(left_glow.modulate.g, center_glow.modulate.g + 0.25)
	assert_gt(left_glow.modulate.g, left_base.g * 1.70)
	assert_gte(int(resonance.call("particle_count")), 30)

	for _step: int in 110:
		resonance.call("_process", 0.05)
	assert_false(bool(resonance.call("is_resonating")))
	assert_eq(int(resonance.call("active_pulse_count")), 0)
	assert_eq(int(resonance.call("particle_count")), 0)
	assert_eq(left_glow.modulate, left_base)
	assert_eq(center_glow.modulate, center_base)


func test_resonance_accepts_water_clicks_only_during_countdown_idle() -> void:
	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var resonance := stage.get_node_or_null("OasisResonance")
	assert_not_null(resonance)
	if resonance == null:
		return

	assert_false(bool(resonance.call(
			"register_water_click", Vector2(160.0, 710.0))))
	resonance.call("set_countdown_idle", true)
	assert_true(bool(resonance.call(
			"register_water_click", Vector2(160.0, 710.0))))
	resonance.call("set_countdown_idle", false, false)
	assert_eq(int(resonance.call("registered_zone_count")), 0)
	assert_false(bool(resonance.call(
			"register_water_click", Vector2(960.0, 710.0))))
