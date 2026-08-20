extends GutTest

const SCENE3_PATH := "res://src/ui/scenes/scene3.tscn"
const EASTER_EGG_SCRIPT_PATH := \
		"res://src/ui/components/scene3_vertical_fish_easter_egg.gd"


func test_successful_cloud_click_roll_launches_a_reusable_vertical_school() -> void:
	assert_true(ResourceLoader.exists(EASTER_EGG_SCRIPT_PATH))
	var stage := (load(SCENE3_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var interaction := stage.get_node_or_null("CloudSeaClickDisturbance") as Control
	var cloud := stage.get_node_or_null("CloudSeaFront") as Control
	var easter_egg := stage.get_node_or_null("VerticalFishEasterEgg")
	assert_not_null(interaction)
	assert_not_null(cloud)
	assert_not_null(easter_egg)
	if interaction == null or cloud == null or easter_egg == null:
		return

	interaction.set("click_cooldown", 0.0)
	easter_egg.set("trigger_delay_sec", 0.0)
	easter_egg.set("trigger_probability", 1.0)
	easter_egg.set("minimum_clicks_before_roll", 1)
	easter_egg.set("retrigger_cooldown", 0.0)
	var cloud_point := cloud.get_global_transform_with_canvas() \
			* Vector2(cloud.size.x * 0.62, cloud.size.y * 0.24)
	assert_true(interaction.call("try_spawn_at_canvas_position", cloud_point))
	var launched_count := int(easter_egg.call("get_active_fish_count"))
	assert_between(launched_count, 2, 3)
	assert_eq(int(easter_egg.call("get_pool_size")), 3)
	assert_true(bool(easter_egg.call("uses_shared_fish_atlas")))
	assert_gt(float(easter_egg.call("fish_vertical_travel")), 700.0)
	assert_lte(float(easter_egg.get("flight_duration")), 0.9)
	assert_lte(float(easter_egg.get("stagger_sec")), 0.04)

	easter_egg.call("_process", 0.38)
	assert_lt(float(easter_egg.call("get_highest_active_fish_y")), 700.0)
	assert_true(interaction.call("try_spawn_at_canvas_position", cloud_point))
	assert_eq(int(easter_egg.call("get_active_fish_count")), launched_count,
			"An active school must not stack another school")

	easter_egg.call("_process", 1.0)
	assert_eq(int(easter_egg.call("get_active_fish_count")), 0)
	assert_true(interaction.call("try_spawn_at_canvas_position", cloud_point))
	assert_between(int(easter_egg.call("get_active_fish_count")), 2, 3,
			"A later successful click roll must be able to launch again")


func test_zero_probability_never_launches_from_cloud_clicks() -> void:
	var stage := (load(SCENE3_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var easter_egg := stage.get_node_or_null("VerticalFishEasterEgg")
	assert_not_null(easter_egg)
	if easter_egg == null:
		return

	easter_egg.set("trigger_probability", 0.0)
	for click_index in 20:
		assert_false(bool(easter_egg.call(
				"register_cloud_click", Vector2(600.0 + click_index, 860.0))))
	assert_eq(int(easter_egg.call("get_active_fish_count")), 0)


func test_default_click_frequency_matches_scene2_rare_fish_rhythm() -> void:
	var stage := (load(SCENE3_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var easter_egg := stage.get_node_or_null("VerticalFishEasterEgg")
	assert_not_null(easter_egg)
	if easter_egg == null:
		return

	assert_between(float(easter_egg.get("trigger_probability")), 0.04, 0.06)
	assert_eq(int(easter_egg.get("minimum_clicks_before_roll")), 3)
	assert_almost_eq(float(easter_egg.get("retrigger_cooldown")), 6.0, 0.01)


func test_rare_fish_waits_three_clicks_and_obeys_retrigger_cooldown() -> void:
	var stage := (load(SCENE3_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var easter_egg := stage.get_node_or_null("VerticalFishEasterEgg")
	assert_not_null(easter_egg)
	if easter_egg == null:
		return

	easter_egg.set("trigger_probability", 1.0)
	easter_egg.set("trigger_delay_sec", 0.0)
	easter_egg.set("minimum_clicks_before_roll", 3)
	easter_egg.set("retrigger_cooldown", 6.0)
	var point := Vector2(900.0, 850.0)
	assert_false(bool(easter_egg.call("register_cloud_click", point)))
	assert_false(bool(easter_egg.call("register_cloud_click", point)))
	assert_true(bool(easter_egg.call("register_cloud_click", point)))
	assert_between(int(easter_egg.call("get_active_fish_count")), 2, 3)

	easter_egg.call("_process", 1.2)
	assert_eq(int(easter_egg.call("get_active_fish_count")), 0)
	assert_false(bool(easter_egg.call("register_cloud_click", point)),
			"The six-second cooldown must outlive the short fish animation")
