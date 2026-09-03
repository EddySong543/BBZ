extends GutTest

const SCENE9_PATH := "res://src/ui/scenes/scene9.tscn"
const FLOCK_SCRIPT_PATH := \
		"res://src/ui/components/scene9_eye_socket_bird_flock.gd"


func _instantiate_stage() -> BattleStage:
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	return stage


func test_flock_uses_small_readable_hard_pixel_birds() -> void:
	var stage := _instantiate_stage()
	var flock := stage.get_node_or_null(
			"DistantLeftMountain/EyeSocketBirdFlock") as Control
	assert_not_null(flock)
	if flock == null:
		return
	assert_eq((flock.get_script() as Script).resource_path, FLOCK_SCRIPT_PATH)
	assert_eq(flock.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_false(flock.visible)
	var contract := flock.call("visual_contract_snapshot") as Dictionary
	assert_eq(contract["construction"], "generated_master_hard_pixel_strip")
	assert_eq(int(contract["bird_count"]), 8)
	assert_eq(int(contract["frame_count"]), 3)
	assert_eq(contract["source_frame_size"], Vector2i(5, 3))
	assert_eq(contract["display_footprint_px"], Vector2i(20, 12))
	assert_eq(int(contract["palette_color_count"]), 2)
	assert_true(bool(contract["hard_alpha_only"]))
	assert_gte(int(contract["minimum_frame_opaque_pixels"]), 6)
	assert_false(bool(contract["uses_particles"]))
	assert_true(bool(contract["uses_opacity_fade"]))
	assert_false(bool(contract["uses_blur"]))
	assert_true(bool(contract["integer_source_positions"]))
	assert_false(bool(contract["socket_pixel_masking"]))
	assert_false(bool(contract["mountain_wide_pixel_occlusion"]))
	assert_false(bool(contract["whole_bird_mountain_occlusion"]))
	assert_true(bool(contract["always_in_front_of_mountain"]))
	assert_eq(contract["mountain_occlusion_strategy"], "none_front_layer")
	assert_false(flock.show_behind_parent)
	assert_eq(contract["parent_draw_order"], "after_parent_no_mask")
	assert_true(bool(contract["cloud_occlusion_by_draw_order"]))
	assert_true(bool(contract["retires_only_after_cloud_occlusion"]))
	assert_false(bool(contract["hard_cut_end"]))
	assert_eq(float(contract["cloud_occlusion_hold_seconds"]), 0.0)
	assert_gte(float(contract["opacity_fade_seconds"]), 0.8)
	assert_true(bool(contract["keeps_moving_during_fade"]))
	assert_gte(float(contract["minimum_fade_travel_source_px"]), 6.0)
	assert_eq(contract["emergence_route"], "diagonal_up_right_arc")
	var source := FileAccess.get_file_as_string(FLOCK_SCRIPT_PATH)
	assert_false(source.contains("_whole_bird_clears_mountain"))
	assert_false(source.contains("_bird_pixel_is_visible"))
	assert_false(source.contains("_mountain_pixel_is_opaque"))


func test_flock_staggers_birds_and_keeps_motion_on_source_pixel_grid() -> void:
	var stage := _instantiate_stage()
	var flock := stage.get_node(
			"DistantLeftMountain/EyeSocketBirdFlock") as Control
	assert_true(bool(flock.call("start_flock")))
	flock.call("advance_for_testing", 0.55)
	var early := flock.call("visible_birds_snapshot") as Array
	assert_gt(early.size(), 1)
	assert_lt(early.size(), 8)
	for bird_variant: Variant in early:
		var bird := bird_variant as Dictionary
		var position := bird["position"] as Vector2
		assert_eq(position, position.round())
		assert_gte(int(bird["frame"]), 0)
		assert_lte(int(bird["frame"]), 2)

	flock.call("advance_for_testing", 0.75)
	var spread := flock.call("visible_birds_snapshot") as Array
	assert_eq(spread.size(), 8)
	var endpoints := flock.call("flight_endpoints_for_testing") as Array
	var unique_y: Dictionary = {}
	for endpoint_variant: Variant in endpoints:
		var endpoint := endpoint_variant as Vector2
		unique_y[int(endpoint.y)] = true
	assert_gte(unique_y.size(), 4)
	assert_true(bool(flock.call("endpoints_are_cloud_covered_for_testing")))


func test_flock_leaves_eye_socket_on_a_diagonal_not_a_vertical_exit() -> void:
	var stage := _instantiate_stage()
	var flock := stage.get_node(
			"DistantLeftMountain/EyeSocketBirdFlock") as Control
	assert_true(bool(flock.call("start_flock")))
	var start := (flock.call("visible_birds_snapshot") as Array)[0] as Dictionary
	flock.call("advance_for_testing", 0.5)
	var moved := (flock.call("visible_birds_snapshot") as Array)[0] as Dictionary
	var delta := (moved["position"] as Vector2) - (start["position"] as Vector2)
	assert_gt(delta.x, 6.0)
	assert_lt(delta.y, -3.0)
	assert_gt(delta.x, absf(delta.y) * 0.8)


func test_flock_keeps_travelling_while_opacity_eases_out() -> void:
	var stage := _instantiate_stage()
	var flock := stage.get_node(
			"DistantLeftMountain/EyeSocketBirdFlock") as Control
	assert_true(bool(flock.call("start_flock")))
	flock.call("advance_for_testing", 2.8)
	var first_states := flock.call("visible_birds_snapshot") as Array
	var first := first_states[0] as Dictionary
	flock.call("advance_for_testing", 0.4)
	var second_states := flock.call("visible_birds_snapshot") as Array
	var second := second_states[0] as Dictionary
	assert_lt(float(second["opacity"]), float(first["opacity"]))
	assert_ne(second["position"], first["position"])
	assert_gt(float(second["opacity"]), 0.0)


func test_valid_environment_click_triggers_repeatable_flock() -> void:
	var stage := _instantiate_stage()
	var flock := stage.get_node(
			"DistantLeftMountain/EyeSocketBirdFlock") as Control
	var controller := stage.get_node("SceneInteractionController")
	var grass_point := controller.call("find_grass_position_for_testing") as Vector2
	stage.call("set_easter_egg_roll_for_testing", 0.0)
	assert_true(bool(stage.call(
			"register_scene_click_at_canvas_position", grass_point)))
	assert_true(flock.visible)
	var triggered := stage.call("easter_egg_contract_snapshot") as Dictionary
	assert_eq(int(triggered["trigger_count"]), 1)
	assert_eq(triggered["effect"], "eye_socket_bird_flock")

	flock.call("advance_for_testing", 6.0)
	assert_false(flock.visible)
	assert_true(bool(stage.call(
			"register_scene_click_at_canvas_position", grass_point)))
	var repeated := stage.call("easter_egg_contract_snapshot") as Dictionary
	assert_eq(int(repeated["trigger_count"]), 2)
