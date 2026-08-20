extends GutTest

const SCENE3_PATH := "res://src/ui/scenes/scene3.tscn"
const INTERACTION_SCRIPT_PATH := \
		"res://src/ui/components/scene3_cloud_interaction.gd"
const CLOUD_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene3_cloud_sea.gdshader"


func test_scene3_cloud_click_keeps_fish_signal_without_direct_dependency() -> void:
	assert_true(ResourceLoader.exists(INTERACTION_SCRIPT_PATH))
	var stage := (load(SCENE3_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var interaction := stage.get_node_or_null("CloudSeaClickDisturbance") as Control
	var easter_egg := stage.get_node_or_null("VerticalFishEasterEgg")

	assert_not_null(interaction)
	assert_false(stage.has_node("FlyingFishClick"))
	assert_true(stage.has_node("FlyingFishFar"))
	assert_true(stage.has_node("FlyingFishNear"))
	assert_not_null(easter_egg)
	if interaction == null or easter_egg == null:
		return
	assert_eq(interaction.mouse_filter, Control.MOUSE_FILTER_PASS)
	assert_eq(interaction.get("cloud_target_path"), NodePath("../CloudSeaFront"))
	assert_eq(interaction.get("secondary_cloud_target_path"),
			NodePath("../CloudSeaMid"))
	assert_eq(interaction.get("tertiary_cloud_target_path"),
			NodePath("../CloudSeaBack"))
	assert_true(interaction.is_connected(
			"cloud_disturbed", Callable(easter_egg, "_on_cloud_disturbed")))

	var source := FileAccess.get_file_as_string(INTERACTION_SCRIPT_PATH)
	assert_false(source.contains("fish_school"),
			"Cloud clicks must not retain a fish-school reference")
	assert_false(source.contains("trigger_school"),
			"Cloud clicks must not call the flying-fish school")
	assert_false(source.contains("FlyingFish"),
			"Cloud clicks must not depend on the flying-fish component")
	assert_false(source.contains("accept_event"))
	assert_false(source.contains("set_input_as_handled"))


func test_scene3_cloud_click_propagates_from_front_to_back() -> void:
	var stage := (load(SCENE3_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var interaction := stage.get_node_or_null("CloudSeaClickDisturbance") as Control
	var cloud := stage.get_node_or_null("CloudSeaFront") as Control
	var mid_cloud := stage.get_node_or_null("CloudSeaMid") as Control
	var back_cloud := stage.get_node_or_null("CloudSeaBack") as Control
	var far_school := stage.get_node_or_null("FlyingFishFar")
	var near_school := stage.get_node_or_null("FlyingFishNear")
	var easter_egg := stage.get_node_or_null("VerticalFishEasterEgg")
	if interaction == null or cloud == null or mid_cloud == null \
			or back_cloud == null or easter_egg == null:
		fail_test("Scene3 must own a dedicated bottom-cloud click response")
		return

	assert_false(interaction.call(
			"try_spawn_at_canvas_position", Vector2(960.0, 520.0)))
	interaction.set("click_cooldown", 0.0)
	easter_egg.set("trigger_probability", 0.0)
	var local_point := Vector2(interaction.size.x * 0.46, 170.0)
	var canvas_point := interaction.get_global_transform_with_canvas() \
			* local_point
	assert_true(interaction.call("try_spawn_at_canvas_position", canvas_point))
	assert_eq(int(interaction.call("active_cloud_effect_count")), 1)
	assert_eq(int(far_school.call("get_active_fish_count")), 0)
	assert_eq(int(near_school.call("get_active_fish_count")), 0)
	var front_material := cloud.material as ShaderMaterial
	var mid_material := mid_cloud.material as ShaderMaterial
	var back_material := back_cloud.material as ShaderMaterial
	assert_between(float(front_material.get_shader_parameter(
			"cloud_press_strength")), 0.7, 0.74)
	assert_eq(float(mid_material.get_shader_parameter(
			"cloud_press_strength")), 0.0)
	assert_eq(float(back_material.get_shader_parameter(
			"cloud_press_strength")), 0.0)
	assert_eq(StringName(interaction.call("get_active_cloud_layer")), &"propagating")
	assert_true(bool(interaction.call("is_cloud_layer_active", &"front")))
	assert_false(bool(interaction.call("is_cloud_layer_active", &"mid")))
	assert_false(bool(interaction.call("is_cloud_layer_active", &"back")))

	var expected_local: Vector2 = interaction.get_global_transform_with_canvas() \
			.affine_inverse() * canvas_point
	var actual_origin: Vector2 = interaction.call("get_last_disturbance_origin")
	assert_almost_eq(actual_origin.x, expected_local.x, 4.0)

	interaction.call("_process", 0.07)
	assert_between(float(front_material.get_shader_parameter(
			"cloud_press_strength")), 0.7, 0.74)
	var mid_strength := float(mid_material.get_shader_parameter(
			"cloud_press_strength"))
	assert_between(mid_strength, 0.44, 0.48)
	assert_eq(float(back_material.get_shader_parameter(
			"cloud_press_strength")), 0.0)
	assert_eq(int(interaction.call("active_cloud_effect_count")), 2)
	assert_true(bool(interaction.call("is_cloud_layer_active", &"front")))
	assert_true(bool(interaction.call("is_cloud_layer_active", &"mid")))

	interaction.call("_process", 0.06)
	assert_between(float(front_material.get_shader_parameter(
			"cloud_press_strength")), 0.7, 0.74)
	assert_between(float(mid_material.get_shader_parameter(
			"cloud_press_strength")), 0.44, 0.48)
	var back_strength := float(back_material.get_shader_parameter(
			"cloud_press_strength"))
	assert_between(back_strength, 0.2, 0.24)
	assert_eq(int(interaction.call("active_cloud_effect_count")), 3)
	assert_true(bool(interaction.call("is_cloud_layer_active", &"front")))
	assert_true(bool(interaction.call("is_cloud_layer_active", &"mid")))
	assert_true(bool(interaction.call("is_cloud_layer_active", &"back")))
	assert_gt(mid_strength, back_strength)
	interaction.call("_process", 1.0)
	assert_eq(int(interaction.call("active_cloud_effect_count")), 0)

	var shader_source := FileAccess.get_file_as_string(CLOUD_SHADER_PATH)
	assert_true(shader_source.contains("cloud_press_strength"))
	assert_true(shader_source.contains("cloud_press_phase"))
	assert_true(shader_source.contains("cloud_press_contour_offset"))
	assert_true(shader_source.contains("center_depression"))
	assert_true(shader_source.contains("shoulder_rise"))
	assert_true(shader_source.contains("rebound"))
	assert_false(shader_source.contains("cloud_puff"))
	assert_false(shader_source.contains("cloud_stir"))
	assert_false(shader_source.contains("tangent_uv"))
	assert_false(shader_source.contains("click_center_cut"),
			"The rejected symmetric ripple split must not remain in the cloud shader")
	var interaction_source := FileAccess.get_file_as_string(INTERACTION_SCRIPT_PATH)
	assert_false(interaction_source.contains("_draw_cloud_roll"))
	assert_false(interaction_source.contains("_draw_puff_cluster"))
	assert_false(interaction_source.contains("draw_rect"))
	assert_false(interaction_source.contains("cloud_light_color"))
	assert_false(interaction_source.contains("cloud_dawn"))
	assert_false(interaction_source.contains("cloud_stir"))
	assert_true(interaction_source.contains("secondary_delay"))
	assert_true(interaction_source.contains("tertiary_delay"))
