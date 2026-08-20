extends GutTest

const SCENE2_PATH := "res://src/ui/scenes/scene2.tscn"
const WATER_INTERACTION_SCRIPT_PATH := \
		"res://src/ui/components/scene2_water_interaction.gd"
const FISH_LEAP_SCRIPT_PATH := \
		"res://src/ui/components/scene2_waterfall_fish_leap.gd"


func test_scene2_water_click_layers_are_visual_only_and_depth_matched() -> void:
	assert_true(ResourceLoader.exists(WATER_INTERACTION_SCRIPT_PATH))
	if not ResourceLoader.exists(WATER_INTERACTION_SCRIPT_PATH):
		return
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var splash := stage.get_node_or_null("WaterfallClickSplash") as Control
	var ripple := stage.get_node_or_null("RiverClickRipple") as Control

	assert_not_null(splash)
	assert_not_null(ripple)
	if splash == null or ripple == null:
		return
	assert_eq(splash.get("effect_kind"), 0)
	assert_eq(ripple.get("effect_kind"), 1)
	assert_eq(splash.get("water_target_path"), NodePath("../Waterfall"))
	assert_eq(ripple.get("water_target_path"), NodePath("../River"))
	assert_eq(splash.mouse_filter, Control.MOUSE_FILTER_PASS)
	assert_eq(ripple.mouse_filter, Control.MOUSE_FILTER_PASS)
	assert_almost_eq(float(splash.get_meta("parallax_factor")), 0.18, 0.001)
	assert_almost_eq(float(ripple.get_meta("parallax_factor")), 1.18, 0.001)

	var source := FileAccess.get_file_as_string(WATER_INTERACTION_SCRIPT_PATH)
	assert_true(source.contains("func _gui_input"))
	assert_false(source.contains("set_input_as_handled"),
			"Water reactions must never consume battle or UI clicks")
	assert_false(source.contains("accept_event"),
			"Water reactions must remain passive after their visual response")


func test_scene2_water_clicks_spawn_only_inside_the_authored_water_regions() -> void:
	if not ResourceLoader.exists(WATER_INTERACTION_SCRIPT_PATH):
		pending("Water interaction component has not been implemented yet")
		return
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var splash := stage.get_node_or_null("WaterfallClickSplash") as Control
	var ripple := stage.get_node_or_null("RiverClickRipple") as Control
	if splash == null or ripple == null:
		fail_test("Scene2 must own separate waterfall and river click layers")
		return
	var waterfall := stage.get_node("Waterfall") as Control
	var river := stage.get_node("River") as Control
	var waterfall_point := waterfall.get_global_transform_with_canvas() \
			* Vector2(360.0, 420.0)
	var river_point := river.get_global_rect().get_center()

	assert_true(splash.call("try_spawn_at_canvas_position", waterfall_point))
	assert_eq(int(splash.call("active_effect_count")), 1)
	assert_false(splash.call("try_spawn_at_canvas_position", Vector2(20.0, 20.0)))
	assert_true(ripple.call("try_spawn_at_canvas_position", river_point))
	assert_eq(int(ripple.call("active_effect_count")), 1)
	assert_false(ripple.call("try_spawn_at_canvas_position", Vector2(20.0, 20.0)))


func test_scene2_waterfall_fish_is_a_passive_depth_matched_easter_egg() -> void:
	assert_true(ResourceLoader.exists(FISH_LEAP_SCRIPT_PATH))
	if not ResourceLoader.exists(FISH_LEAP_SCRIPT_PATH):
		return
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var fish := stage.get_node_or_null("WaterfallFishLeap") as Control
	assert_not_null(fish)
	if fish == null:
		return
	assert_eq(fish.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(fish.get("water_target_path"), NodePath("../Waterfall"))
	assert_almost_eq(float(fish.get_meta("parallax_factor")), 0.18, 0.001)
	assert_true(bool(fish.call("fish_texture_ready")))
	var source := FileAccess.get_file_as_string(FISH_LEAP_SCRIPT_PATH)
	assert_false(source.contains("func _gui_input"))
	assert_false(source.contains("func _input"))
	assert_false(source.contains("set_input_as_handled"))


func test_scene2_fish_waits_for_multiple_clicks_then_leaps_with_vertical_drop() -> void:
	if not ResourceLoader.exists(FISH_LEAP_SCRIPT_PATH):
		pending("Waterfall fish leap has not been implemented yet")
		return
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var splash := stage.get_node_or_null("WaterfallClickSplash") as Control
	var fish := stage.get_node_or_null("WaterfallFishLeap") as Control
	if splash == null or fish == null:
		fail_test("Scene2 must connect the waterfall click layer to the fish leap layer")
		return
	splash.set("click_cooldown", 0.0)
	fish.set("trigger_clicks", 3)
	fish.set("trigger_chance", 1.0)
	fish.set("pity_clicks", 7)
	var waterfall := stage.get_node("Waterfall") as Control
	var waterfall_point := waterfall.get_global_transform_with_canvas() \
			* Vector2(360.0, 420.0)

	for _click_index in 2:
		assert_true(splash.call("try_spawn_at_canvas_position", waterfall_point))
	assert_eq(int(fish.call("active_fish_count")), 0)
	assert_true(splash.call("try_spawn_at_canvas_position", waterfall_point))
	assert_eq(int(fish.call("active_fish_count")), 1)
	var expected_start: Vector2 = fish.get_global_transform_with_canvas().affine_inverse() \
			* waterfall_point
	expected_start = (expected_start / float(fish.get("pixel_size"))).round() \
			* float(fish.get("pixel_size"))
	assert_almost_eq(
			(fish.call("fish_start_position") as Vector2).x,
			expected_start.x,
			0.01,
			"Fish must emerge at the triggering waterfall click X")
	assert_almost_eq(
			(fish.call("fish_start_position") as Vector2).y,
			expected_start.y,
			0.01,
			"Fish must emerge at the triggering waterfall click Y")
	assert_gt(float(fish.call("fish_vertical_drop")), 240.0,
			"Fish must visibly travel from the upper fall into a lower section")
	assert_true(bool(fish.call("fish_starts_above_landing")))


func test_scene2_fish_has_no_separate_fin_pixels() -> void:
	if not ResourceLoader.exists(FISH_LEAP_SCRIPT_PATH):
		pending("Waterfall fish leap has not been implemented yet")
		return
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var fish := stage.get_node_or_null("WaterfallFishLeap") as Control
	if fish == null:
		fail_test("Scene2 must own a waterfall fish leap layer")
		return
	var fish_image := fish.call("fish_asset_image") as Image
	assert_not_null(fish_image)
	if fish_image == null:
		return
	assert_almost_eq(fish_image.get_pixel(10, 8).a, 0.0, 0.001,
			"The lower fin pixel must be removed")
	assert_almost_eq(fish_image.get_pixel(11, 8).a, 0.0, 0.001,
			"The lower fin pixel must be removed")


func test_scene2_golden_fish_reuses_the_finless_shape_with_a_gold_palette() -> void:
	if not ResourceLoader.exists(FISH_LEAP_SCRIPT_PATH):
		pending("Waterfall fish leap has not been implemented yet")
		return
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var fish := stage.get_node_or_null("WaterfallFishLeap") as Control
	if fish == null:
		fail_test("Scene2 must own a waterfall fish leap layer")
		return
	var normal_image := fish.call("fish_asset_image") as Image
	var golden_image := fish.call("golden_fish_asset_image") as Image
	assert_not_null(golden_image)
	if normal_image == null or golden_image == null:
		return
	for y in normal_image.get_height():
		for x in normal_image.get_width():
			assert_almost_eq(golden_image.get_pixel(x, y).a,
					normal_image.get_pixel(x, y).a, 0.001,
					"Golden fish must reuse the normal fish silhouette")
	var golden_body := golden_image.get_pixel(10, 4)
	assert_gt(golden_body.r, golden_body.b,
			"Golden fish body must visibly use a warm gold palette")
	assert_almost_eq(golden_image.get_pixel(10, 8).a, 0.0, 0.001)
	assert_almost_eq(golden_image.get_pixel(11, 8).a, 0.0, 0.001)


func test_scene2_top_waterfall_can_trigger_normal_fish_but_never_golden_fish() -> void:
	if not ResourceLoader.exists(FISH_LEAP_SCRIPT_PATH):
		pending("Waterfall fish leap has not been implemented yet")
		return
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var splash := stage.get_node_or_null("WaterfallClickSplash") as Control
	var fish := stage.get_node_or_null("WaterfallFishLeap") as Control
	if splash == null or fish == null:
		fail_test("Scene2 must connect the waterfall click layer to the fish leap layer")
		return
	splash.set("click_cooldown", 0.0)
	fish.set("trigger_clicks", 2)
	fish.set("trigger_chance", 1.0)
	fish.set("golden_fish_chance", 1.0)
	var waterfall := stage.get_node("Waterfall") as Control
	var top_point := waterfall.get_global_transform_with_canvas() \
			* Vector2(360.0, 300.0)
	assert_true(splash.call("try_spawn_at_canvas_position", top_point))
	assert_true(splash.call("try_spawn_at_canvas_position", top_point))
	assert_eq(int(fish.call("active_fish_count")), 1)
	assert_false(bool(fish.call("is_golden_fish_active")),
			"Top waterfall clicks must keep the normal fish branch only")
	assert_gt(float(fish.call("fish_vertical_drop")), 0.0)


func test_scene2_golden_fish_is_a_rare_upstream_leap_from_middle_waterfall() -> void:
	if not ResourceLoader.exists(FISH_LEAP_SCRIPT_PATH):
		pending("Waterfall fish leap has not been implemented yet")
		return
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var splash := stage.get_node_or_null("WaterfallClickSplash") as Control
	var fish := stage.get_node_or_null("WaterfallFishLeap") as Control
	if splash == null or fish == null:
		fail_test("Scene2 must connect the waterfall click layer to the fish leap layer")
		return
	splash.set("click_cooldown", 0.0)
	fish.set("trigger_clicks", 2)
	fish.set("trigger_chance", 1.0)
	fish.set("golden_fish_chance", 1.0)
	var waterfall := stage.get_node("Waterfall") as Control
	var middle_point := waterfall.get_global_transform_with_canvas() \
			* Vector2(360.0, 620.0)
	assert_true(splash.call("try_spawn_at_canvas_position", middle_point))
	assert_true(splash.call("try_spawn_at_canvas_position", middle_point))
	assert_eq(int(fish.call("active_fish_count")), 1)
	assert_true(bool(fish.call("is_golden_fish_active")))
	assert_lt(float(fish.call("fish_vertical_drop")), -240.0,
			"Golden fish must leap upward and re-enter the upstream water")


func test_scene2_fish_pity_limit_prevents_an_invisible_unlucky_streak() -> void:
	if not ResourceLoader.exists(FISH_LEAP_SCRIPT_PATH):
		pending("Waterfall fish leap has not been implemented yet")
		return
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var splash := stage.get_node_or_null("WaterfallClickSplash") as Control
	var fish := stage.get_node_or_null("WaterfallFishLeap") as Control
	if splash == null or fish == null:
		fail_test("Scene2 must connect the waterfall click layer to the fish leap layer")
		return
	splash.set("click_cooldown", 0.0)
	fish.set("trigger_clicks", 3)
	fish.set("trigger_chance", 0.0)
	fish.set("pity_clicks", 5)
	var waterfall := stage.get_node("Waterfall") as Control
	var waterfall_point := waterfall.get_global_transform_with_canvas() \
			* Vector2(360.0, 420.0)

	for _click_index in 4:
		assert_true(splash.call("try_spawn_at_canvas_position", waterfall_point))
	assert_eq(int(fish.call("active_fish_count")), 0)
	assert_true(splash.call("try_spawn_at_canvas_position", waterfall_point))
	assert_eq(int(fish.call("active_fish_count")), 1)
