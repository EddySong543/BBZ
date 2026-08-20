extends GutTest

const SCENE4_PATH := "res://src/ui/scenes/scene4.tscn"
const INTERACTION_SCRIPT_PATH := (
		"res://src/ui/components/scene4_click_interaction.gd")
const CLICK_TARGET_SCRIPT_PATH := (
		"res://src/ui/components/scene4_click_target.gd")
const ACHIEVEMENT_SPIRIT_SCRIPT_PATH := (
		"res://src/ui/components/scene4_leaf_spirit_swarm.gd")


func test_scene4_click_targets_use_visible_pixels_and_keep_authored_transforms() -> void:
	var stage := (load(SCENE4_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	await get_tree().process_frame
	var interaction := stage.get_node_or_null("ClickInteraction")
	assert_not_null(interaction)
	if interaction == null:
		return
	assert_eq(interaction.get_script().resource_path, INTERACTION_SCRIPT_PATH)

	for tree_name: String in ["LeftTree2", "RightTree2"]:
		var tree := stage.get_node(tree_name) as TextureRect
		assert_null(tree.get_script())
		assert_eq(tree.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_false(bool(interaction.call(
				"trigger_target", StringName(tree_name))))

	var top_leaves := stage.get_node("BackgroundTopLeaves2") as TextureRect
	assert_null(top_leaves.get_script())
	assert_eq(top_leaves.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_false(bool(interaction.call(
			"trigger_target", &"BackgroundTopLeaves2")))
	assert_false(stage.has_node("LeafSpirits"))
	assert_true(stage.has_node("AchievementLeafSpirits"))
	var top_material := top_leaves.material as ShaderMaterial
	assert_false(top_material.shader.code.contains("click_impulse"))

	for target_name: String in [
		"RuinStone1",
		"RuinStone2",
		"RuinStone3",
		"RuinStone4",
	]:
		var target := stage.get_node(target_name) as TextureRect
		assert_eq(target.get_script().resource_path, CLICK_TARGET_SCRIPT_PATH)
		assert_eq(target.mouse_filter, Control.MOUSE_FILTER_PASS)
		var hit_point := _find_visible_hit_point(stage, interaction, target_name)
		assert_false(hit_point.is_equal_approx(Vector2.INF),
				"%s 必须存在不被更近层遮挡的可点击实体像素" % target_name)
		if not hit_point.is_equal_approx(Vector2.INF):
			assert_eq(String(interaction.call("get_hit_target_at", hit_point)), target_name)

func test_scene4_top_leaves_remain_outside_achievement_interaction() -> void:
	var stage := (load(SCENE4_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	await get_tree().process_frame
	var interaction := stage.get_node("ClickInteraction")
	var top_leaves := stage.get_node("BackgroundTopLeaves2") as TextureRect
	var top_position := top_leaves.position
	var top_scale := top_leaves.scale

	assert_false(stage.has_node("LeafSpirits"))
	var spirits := stage.get_node("AchievementLeafSpirits")
	assert_eq(spirits.get_script().resource_path, ACHIEVEMENT_SPIRIT_SCRIPT_PATH)
	assert_eq(int(spirits.call("get_active_spirit_count")), 0)
	assert_false(bool(interaction.call("trigger_target", &"BackgroundTopLeaves2")))
	assert_eq(int(interaction.call(
			"get_trigger_count", &"BackgroundTopLeaves2")), 0)
	assert_eq(top_leaves.position, top_position)
	assert_eq(top_leaves.scale, top_scale)
	var top_material := top_leaves.material as ShaderMaterial
	assert_false(top_material.shader.code.contains("click_impulse"))


func test_scene4_achievement_requires_low_to_high_stones_within_eight_seconds() -> void:
	var stage := (load(SCENE4_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	await get_tree().process_frame
	var interaction := stage.get_node("ClickInteraction")
	var spirits := stage.get_node("AchievementLeafSpirits")

	assert_eq(float(interaction.achievement_window_sec), 8.0)
	assert_eq(float(interaction.achievement_cooldown_sec), 30.0)
	assert_false(bool(interaction.call("is_achievement_completed")))
	for stone_name: StringName in [
		&"RuinStone4",
		&"RuinStone2",
		&"RuinStone3",
		&"RuinStone1",
	]:
		assert_true(bool(interaction.call("trigger_target", stone_name)))

	assert_true(bool(interaction.call("is_achievement_completed")))
	assert_true(bool(interaction.call("is_achievement_on_cooldown")))
	assert_eq(int(interaction.call("get_achievement_trigger_count")), 1)
	assert_eq(int(interaction.call("get_achievement_progress")), 0)
	var first_swarm_count := int(spirits.call("get_active_spirit_count"))
	assert_gte(first_swarm_count, 18)
	assert_lte(first_swarm_count, 24)
	for stone_name: String in [
		"RuinStone1", "RuinStone2", "RuinStone3", "RuinStone4",
	]:
		var material := (
				stage.get_node(stone_name) as TextureRect
		).material as ShaderMaterial
		assert_eq(float(material.get_shader_parameter("achievement_glow")), 1.0)
		assert_eq(float(material.get_shader_parameter("achievement_sync")), 1.0)
		assert_true(material.shader.code.contains("achievement_glow"))
		assert_true(material.shader.code.contains("achievement_sync"))
	for stone_name: StringName in [
		&"RuinStone4", &"RuinStone2", &"RuinStone3", &"RuinStone1",
	]:
		interaction.call("trigger_target", stone_name)
	assert_eq(int(spirits.call("get_active_spirit_count")), first_swarm_count,
			"冷却期间不能重复召唤")
	assert_eq(int(interaction.call("get_achievement_trigger_count")), 1)
	assert_eq(int(interaction.call("get_achievement_progress")), 0)


func test_scene4_achievement_resets_on_wrong_order_and_timeout() -> void:
	var wrong_stage := (load(SCENE4_PATH) as PackedScene).instantiate()
	add_child_autofree(wrong_stage)
	await get_tree().process_frame
	var wrong_interaction := wrong_stage.get_node("ClickInteraction")
	wrong_interaction.call("trigger_target", &"RuinStone4")
	wrong_interaction.call("trigger_target", &"RuinStone1")
	assert_eq(int(wrong_interaction.call("get_achievement_progress")), 0)
	for stone_name: StringName in [
		&"RuinStone2", &"RuinStone3", &"RuinStone1",
	]:
		wrong_interaction.call("trigger_target", stone_name)
	assert_false(bool(wrong_interaction.call("is_achievement_completed")))
	assert_eq(int((wrong_stage.get_node("AchievementLeafSpirits")).call(
			"get_active_spirit_count")), 0)

	var timeout_stage := (load(SCENE4_PATH) as PackedScene).instantiate()
	add_child_autofree(timeout_stage)
	await get_tree().process_frame
	var timeout_interaction := timeout_stage.get_node("ClickInteraction")
	timeout_interaction.achievement_window_sec = 0.04
	timeout_interaction.call("trigger_target", &"RuinStone4")
	await get_tree().create_timer(0.07).timeout
	assert_eq(int(timeout_interaction.call("get_achievement_progress")), 0)
	for stone_name: StringName in [
		&"RuinStone2", &"RuinStone3", &"RuinStone1",
	]:
		timeout_interaction.call("trigger_target", stone_name)
	assert_false(bool(timeout_interaction.call("is_achievement_completed")))


func test_scene4_achievement_energy_restores_after_the_brief_effect() -> void:
	var stage := (load(SCENE4_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	await get_tree().process_frame
	var interaction := stage.get_node("ClickInteraction")
	interaction.achievement_sync_hold_sec = 0.04
	interaction.achievement_sync_fall_sec = 0.04
	interaction.achievement_glow_hold_sec = 0.04
	interaction.achievement_glow_fall_sec = 0.04
	for stone_name: StringName in [
		&"RuinStone4", &"RuinStone2", &"RuinStone3", &"RuinStone1",
	]:
		interaction.call("trigger_target", stone_name)
	await get_tree().create_timer(0.12).timeout
	for stone_name: String in [
		"RuinStone1", "RuinStone2", "RuinStone3", "RuinStone4",
	]:
		var material := (
				stage.get_node(stone_name) as TextureRect
		).material as ShaderMaterial
		assert_lte(float(material.get_shader_parameter("achievement_sync")), 0.05)
		assert_lte(float(material.get_shader_parameter("achievement_glow")), 0.05)


func test_scene4_achievement_can_retrigger_only_after_long_cooldown() -> void:
	var stage := (load(SCENE4_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	await get_tree().process_frame
	var interaction := stage.get_node("ClickInteraction")
	interaction.achievement_cooldown_sec = 0.08
	interaction.achievement_sync_hold_sec = 0.02
	interaction.achievement_sync_fall_sec = 0.02
	interaction.achievement_glow_hold_sec = 0.02
	interaction.achievement_glow_fall_sec = 0.02
	var sequence: Array[StringName] = [
		&"RuinStone4", &"RuinStone2", &"RuinStone3", &"RuinStone1",
	]
	for stone_name: StringName in sequence:
		interaction.call("trigger_target", stone_name)
	assert_eq(int(interaction.call("get_achievement_trigger_count")), 1)
	assert_true(bool(interaction.call("is_achievement_on_cooldown")))

	for stone_name: StringName in sequence:
		interaction.call("trigger_target", stone_name)
	assert_eq(int(interaction.call("get_achievement_trigger_count")), 1)
	assert_eq(int(interaction.call("get_achievement_progress")), 0)

	await get_tree().create_timer(0.11).timeout
	assert_false(bool(interaction.call("is_achievement_on_cooldown")))
	for stone_name: StringName in sequence:
		interaction.call("trigger_target", stone_name)
	assert_eq(int(interaction.call("get_achievement_trigger_count")), 2)
	assert_true(bool(interaction.call("is_achievement_on_cooldown")))


func test_scene4_ruin_clicks_trigger_flash_without_changing_energy_flow() -> void:
	var stage := (load(SCENE4_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	await get_tree().process_frame
	var interaction := stage.get_node("ClickInteraction")
	assert_gte(float(interaction.relic_flash_hold_sec), 0.14)
	assert_gte(float(interaction.relic_flash_fall_sec), 0.68)

	for stone_name: String in [
		"RuinStone1",
		"RuinStone2",
		"RuinStone3",
		"RuinStone4",
	]:
		var stone := stage.get_node(stone_name) as TextureRect
		var stone_position := stone.position
		var stone_scale := stone.scale
		var stone_material := stone.material as ShaderMaterial
		var flow_speed := float(stone_material.get_shader_parameter("pulse_speed"))
		assert_true(bool(interaction.call("trigger_target", StringName(stone_name))))
		assert_eq(stone.position, stone_position)
		assert_eq(stone.scale, stone_scale)
		await get_tree().create_timer(0.1).timeout
		assert_gte(float(stone_material.get_shader_parameter(
				"interaction_flash")), 0.8)
		assert_true(stone_material.shader.code.contains("interaction_flash"))
		assert_false(stone_material.shader.code.contains("interaction_energy"))
		assert_true(stone_material.shader.code.contains(
				"moving_flash = embedded_energy * flash"))
		assert_gte(float(stone_material.get_shader_parameter(
				"interaction_flash_gain")), 1.15)
		assert_false(stone_material.shader.code.contains(
				"carved_track * surface_response * flash"))
		assert_eq(float(stone_material.get_shader_parameter("pulse_speed")), flow_speed)
		assert_lte(float(stone_material.get_shader_parameter("circuit_tail")), 0.26)

	await get_tree().create_timer(0.7).timeout
	for stone_name: String in [
		"RuinStone1",
		"RuinStone2",
		"RuinStone3",
		"RuinStone4",
	]:
		var material := (
				stage.get_node(stone_name) as TextureRect
		).material as ShaderMaterial
		assert_lte(float(material.get_shader_parameter("interaction_flash")), 0.05)


func _find_visible_hit_point(
		stage: Control,
		interaction: Node,
		target_name: String
) -> Vector2:
	var target := stage.get_node(target_name) as TextureRect
	var image := target.texture.get_image()
	if image == null or image.is_empty():
		return Vector2.INF
	var step_x := maxi(1, image.get_width() / 48)
	var step_y := maxi(1, image.get_height() / 48)
	for image_y: int in range(0, image.get_height(), step_y):
		for image_x: int in range(0, image.get_width(), step_x):
			if image.get_pixel(image_x, image_y).a < 0.2:
				continue
			var uv := Vector2(
					(float(image_x) + 0.5) / float(image.get_width()),
					(float(image_y) + 0.5) / float(image.get_height()))
			if target.flip_h:
				uv.x = 1.0 - uv.x
			if target.flip_v:
				uv.y = 1.0 - uv.y
			var screen_point := target.get_global_transform_with_canvas() \
					* (uv * target.size)
			if String(interaction.call("get_hit_target_at", screen_point)) == target_name:
				return screen_point
	return Vector2.INF
