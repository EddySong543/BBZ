extends GutTest

const SCENE9_PATH := "res://src/ui/scenes/scene9.tscn"
const BATTLE_SCREEN9_PATH := "res://src/ui/battle_screen9.tscn"
const CLOUD_SCRIPT_PATH := \
		"res://src/ui/components/scene9_distant_pixel_cloud_bank.gd"
const STAGE_SCRIPT_PATH := \
		"res://src/ui/components/scene9_battle_stage.gd"
const INTERACTION_SCRIPT_PATH := \
		"res://src/ui/components/scene9_interaction_controller.gd"


func _find_opaque_source_pixel(
		cloud: TextureRect, zone: int, frame_index: int = 0) -> Vector2i:
	var image := cloud.call("render_frame_for_testing", frame_index) as Image
	var core_x := int(cloud.call("core_origin_x"))
	var source_size := (cloud.call("authored_signature") as Dictionary)[
			"source_size"] as Vector2i
	var zone_start := core_x + int(floor(float(source_size.x) * float(zone) / 3.0))
	var zone_end := core_x + int(floor(float(source_size.x) * float(zone + 1) / 3.0))
	for y: int in image.get_height():
		for x: int in range(zone_start, zone_end):
			if image.get_pixel(x, y).a >= 0.5:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _canvas_point_for_zone(cloud: TextureRect, zone: int) -> Vector2:
	var visible_frame := int(cloud.call("visible_frame_for_testing"))
	var source_pixel := _find_opaque_source_pixel(cloud, zone, visible_frame)
	assert_gte(source_pixel.x, 0)
	return cloud.call("source_pixel_canvas_position", source_pixel) as Vector2


func _exclusive_canvas_point(
		target: TextureRect, blocker: TextureRect) -> Vector2:
	var frame := target.call(
			"render_frame_for_testing",
			int(target.call("visible_frame_for_testing"))) as Image
	for y: int in range(0, frame.get_height(), 2):
		for x: int in range(0, frame.get_width(), 2):
			if frame.get_pixel(x, y).a <= 0.0:
				continue
			var canvas_position := target.call(
					"source_pixel_canvas_position", Vector2i(x, y)) as Vector2
			if canvas_position.x < 0.0 or canvas_position.x >= 1920.0 \
					or canvas_position.y < 0.0 or canvas_position.y >= 1080.0:
				continue
			if not bool(blocker.call(
					"has_opaque_pixel_at_canvas_position", canvas_position)):
				return canvas_position
	return Vector2(-1.0, -1.0)


func _opaque_canvas_point_for_control(target: Control) -> Vector2:
	var texture := target.get("texture") as Texture2D
	if texture == null:
		return Vector2(-1.0, -1.0)
	var image := texture.get_image()
	for y: int in range(0, image.get_height(), 2):
		for x: int in range(0, image.get_width(), 2):
			if image.get_pixel(x, y).a < 0.2:
				continue
			var local_position := Vector2(
					(float(x) + 0.5) / image.get_width() * target.size.x,
					(float(y) + 0.5) / image.get_height() * target.size.y)
			var canvas_position := (
					target.get_global_transform_with_canvas() * local_position)
			if canvas_position.x >= 0.0 and canvas_position.x < 1920.0 \
					and canvas_position.y >= 0.0 and canvas_position.y < 1080.0:
				return canvas_position
	return Vector2(-1.0, -1.0)


func _grass_cloud_overlap_point(
		stage: BattleStage, controller: Node, cloud: TextureRect) -> Vector2:
	for target_name: String in [
			"DistantLeft", "DistantLeft2", "DistantRight", "DistantRight2"]:
		var target := stage.get_node(target_name) as Control
		var texture := target.get("texture") as Texture2D
		var image := texture.get_image()
		for y: int in range(0, image.get_height(), 2):
			for x: int in range(0, image.get_width(), 2):
				if image.get_pixel(x, y).a < 0.2:
					continue
				var local_position := Vector2(
						(float(x) + 0.5) / image.get_width() * target.size.x,
						(float(y) + 0.5) / image.get_height() * target.size.y)
				var canvas_position := (
						target.get_global_transform_with_canvas() * local_position)
				if canvas_position.x < 0.0 or canvas_position.x >= 1920.0 \
						or canvas_position.y < 0.0 or canvas_position.y >= 1080.0:
					continue
				if bool(controller.call(
						"_target_has_opaque_pixel_at", target, canvas_position)) \
						and bool(cloud.call(
								"has_opaque_pixel_at_canvas_position", canvas_position)):
					return canvas_position
	return Vector2(-1.0, -1.0)


func test_scene9_cloud_click_requires_current_opaque_pixels() -> void:
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var cloud := stage.get_node("DistantPixelCloudBank") as TextureRect
	assert_eq((stage.get_script() as Script).resource_path, STAGE_SCRIPT_PATH)
	assert_eq((cloud.get_script() as Script).resource_path, CLOUD_SCRIPT_PATH)
	var transparent_canvas := cloud.call(
			"source_pixel_canvas_position", Vector2i(0, 0)) as Vector2
	assert_false(bool(stage.call(
			"register_cloud_click_at_canvas_position", transparent_canvas)))
	var center_canvas := _canvas_point_for_zone(cloud, 1)
	assert_true(bool(stage.call(
			"register_cloud_click_at_canvas_position", center_canvas)))
	var ripple := cloud.call("ripple_contract_snapshot") as Dictionary
	assert_true(bool(ripple["active"]))
	assert_true(bool(ripple["requires_alpha_hit"]))
	assert_true(bool(ripple["bottom_locked"]))


func test_scene9_repeated_cloud_clicks_overlap_without_refreshing_prior_ripple() -> void:
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var cloud := stage.get_node("DistantPixelCloudBank") as TextureRect
	var center_canvas := _canvas_point_for_zone(cloud, 1)
	assert_true(bool(stage.call(
			"register_cloud_click_at_canvas_position", center_canvas)))
	cloud.call("advance_ripples_for_testing", 0.24)
	assert_true(bool(stage.call(
			"register_cloud_click_at_canvas_position", center_canvas)))
	var ripple := cloud.call("ripple_contract_snapshot") as Dictionary
	assert_eq(int(ripple["active_count"]), 2)
	assert_eq(int(ripple["maximum_simultaneous_ripples"]), 3)
	assert_true(bool(ripple["same_region_overlap"]))
	var ages := ripple["active_ages_seconds"] as Array
	assert_gt(float(ages[0]), float(ages[1]))


func test_scene9_copied_rear_cloud_receives_alpha_accurate_clicks() -> void:
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var front := stage.get_node("DistantPixelCloudBank") as TextureRect
	var rear := stage.get_node("DistantPixelCloudBank2") as TextureRect
	assert_eq(int(stage.call("interactive_cloud_count_for_testing")), 2)
	var rear_only_point := _exclusive_canvas_point(rear, front)
	assert_gte(rear_only_point.x, 0.0)
	assert_true(bool(stage.call(
			"register_cloud_click_at_canvas_position", rear_only_point)))
	assert_true(bool((rear.call("ripple_contract_snapshot") as Dictionary)[
			"active"]))
	assert_false(bool((front.call("ripple_contract_snapshot") as Dictionary)[
			"active"]))


func test_scene9_clicks_use_scene8_style_input_chain() -> void:
	var controller_source := FileAccess.get_file_as_string(INTERACTION_SCRIPT_PATH)
	assert_true(controller_source.contains("func _input"))
	assert_true(controller_source.contains("set_process_input(true)"))
	assert_false(controller_source.contains("func _unhandled_input"))
	assert_false(controller_source.contains("set_input_as_handled"))
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var controller := stage.get_node("SceneInteractionController")
	var cloud := stage.get_node("DistantPixelCloudBank") as TextureRect
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = _canvas_point_for_zone(cloud, 0)
	event.pressed = true
	controller.call("_input", event)
	assert_eq(int(controller.call("left_click_input_count_for_testing")), 1)
	assert_true(bool((cloud.call("ripple_contract_snapshot") as Dictionary)[
			"active"]))


func test_battle_screen9_routes_real_environment_click() -> void:
	var battle := (load(BATTLE_SCREEN9_PATH) as PackedScene).instantiate()
	add_child_autofree(battle)
	await get_tree().process_frame
	var controller := battle.find_child(
			"SceneInteractionController", true, false)
	assert_not_null(controller)
	if controller == null:
		return
	var stage := controller.get_parent() as BattleStage
	var cloud := stage.get_node("DistantPixelCloudBank") as TextureRect
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = _canvas_point_for_zone(cloud, 0)
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	assert_eq(int(controller.call("left_click_input_count_for_testing")), 1)


func test_scene9_silver_grass_click_throws_scene5_style_chaff() -> void:
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var controller := stage.get_node("SceneInteractionController")
	var grass_position := Vector2(controller.call(
			"find_grass_position_for_testing"))
	assert_gte(grass_position.x, 0.0)
	assert_true(bool(controller.call(
			"trigger_grass_at_canvas_position", grass_position)))
	var contract := controller.call(
			"grass_response_contract_for_testing") as Dictionary
	assert_eq(contract["hit_test"], "source_alpha")
	assert_eq(contract["response"], "scene5_upward_silver_chaff")
	assert_eq(int(contract["active_group_count"]), 1)
	assert_eq(int(contract["maximum_simultaneous_groups"]), 3)
	assert_eq(int(contract["particle_layer_count"]), 9)
	var foreground_mid := stage.get_node("ForegroundMid") as Control
	var foreground_point := _opaque_canvas_point_for_control(foreground_mid)
	assert_gte(foreground_point.x, 0.0)
	assert_same(controller.call(
			"_grass_target_at_canvas_position", foreground_point), foreground_mid)


func test_scene9_repeated_grass_clicks_use_separate_live_groups() -> void:
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var controller := stage.get_node("SceneInteractionController")
	var grass_position := Vector2(controller.call(
			"find_grass_position_for_testing"))
	assert_true(bool(controller.call(
			"trigger_grass_at_canvas_position", grass_position)))
	assert_true(bool(controller.call(
			"trigger_grass_at_canvas_position", grass_position)))
	var contract := controller.call(
			"grass_response_contract_for_testing") as Dictionary
	assert_eq(int(contract["active_group_count"]), 2)
	assert_eq(int(contract["spawn_count"]), 2)
	assert_eq(float(contract["cooldown_seconds"]), 0.0)
	assert_true(bool(contract["same_region_overlap"]))


func test_scene9_visible_grass_wins_over_cloud_pixels_behind_it() -> void:
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var controller := stage.get_node("SceneInteractionController")
	var front_cloud := stage.get_node("DistantPixelCloudBank") as TextureRect
	var overlap_point := _grass_cloud_overlap_point(stage, controller, front_cloud)
	assert_gte(overlap_point.x, 0.0)
	assert_true(bool(stage.call(
			"register_scene_click_at_canvas_position", overlap_point)))
	assert_false(bool((front_cloud.call(
			"ripple_contract_snapshot") as Dictionary)["active"]))
