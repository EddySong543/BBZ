extends GutTest

const SCENE7_PATH := "res://src/ui/scenes/scene7.tscn"
const WATER_INTERACTION_SCRIPT_PATH := \
		"res://src/ui/components/scene2_water_interaction.gd"


func test_scene7_reuses_the_mature_passive_pixel_ripple_component() -> void:
	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var rear := stage.get_node_or_null("RearSpringClickRipple") as Control
	var front := stage.get_node_or_null("FrontSpringClickRipple") as Control
	assert_not_null(rear)
	assert_not_null(front)
	if rear == null or front == null:
		return
	for ripple: Control in [rear, front]:
		assert_eq((ripple.get_script() as Script).resource_path,
				WATER_INTERACTION_SCRIPT_PATH)
		assert_eq(int(ripple.get("effect_kind")), 1)
		assert_eq(ripple.get("water_target_path"), NodePath("."))
		assert_eq(ripple.mouse_filter, Control.MOUSE_FILTER_PASS)
		assert_eq(ripple.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_almost_eq(float(rear.get_meta("parallax_factor")), 0.55, 0.001)
	assert_almost_eq(float(front.get_meta("parallax_factor")), 1.0, 0.001)
	assert_lt(stage.get_node("RearWater").get_index(), rear.get_index())
	assert_lt(rear.get_index(), stage.get_node("OasisMotesFar").get_index())
	assert_lt(stage.get_node("FrontWater").get_index(), front.get_index())
	assert_lt(front.get_index(), stage.get_node("PlatformSpringContact").get_index())

	var source := FileAccess.get_file_as_string(WATER_INTERACTION_SCRIPT_PATH)
	assert_true(source.contains("func _gui_input"))
	assert_true(source.contains("MOUSE_BUTTON_LEFT"))
	assert_true(source.contains("queue_redraw"))
	assert_false(source.contains("set_input_as_handled"))
	assert_false(source.contains("accept_event"))


func test_scene7_clicks_spawn_only_inside_the_two_exposed_spring_bands() -> void:
	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var rear := stage.get_node("RearSpringClickRipple") as Control
	var front := stage.get_node("FrontSpringClickRipple") as Control
	rear.set("click_cooldown", 0.0)
	front.set("click_cooldown", 0.0)
	var rear_center := rear.get_global_transform_with_canvas() * (rear.size * 0.5)
	var front_center := front.get_global_transform_with_canvas() * (front.size * 0.5)
	assert_true(bool(rear.call("try_spawn_at_canvas_position", rear_center)))
	assert_eq(int(rear.call("active_effect_count")), 1)
	assert_true(bool(front.call("try_spawn_at_canvas_position", front_center)))
	assert_eq(int(front.call("active_effect_count")), 1)
	var rear_outside := rear.get_global_transform_with_canvas() * Vector2(-8.0, -8.0)
	var front_outside := front.get_global_transform_with_canvas() \
			* Vector2(front.size.x + 8.0, front.size.y + 8.0)
	assert_false(bool(rear.call("try_spawn_at_canvas_position", rear_outside)))
	assert_false(bool(front.call("try_spawn_at_canvas_position", front_outside)))


func test_scene7_left_click_drives_a_visible_lifetime_without_consuming_input() -> void:
	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var ripple := stage.get_node("FrontSpringClickRipple") as Control
	ripple.set("click_cooldown", 0.0)
	var left_click := InputEventMouseButton.new()
	left_click.button_index = MOUSE_BUTTON_LEFT
	left_click.pressed = true
	left_click.position = ripple.size * 0.5
	ripple.call("_gui_input", left_click)
	assert_eq(int(ripple.call("active_effect_count")), 1)
	assert_true(ripple.is_processing())
	ripple.call("_process", float(ripple.get("effect_lifetime")) + 0.01)
	assert_eq(int(ripple.call("active_effect_count")), 0)
	assert_false(ripple.is_processing())

	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	right_click.position = ripple.size * 0.5
	ripple.call("_gui_input", right_click)
	assert_eq(int(ripple.call("active_effect_count")), 0)


func test_scene7_click_bands_do_not_cover_platform_or_contact_line() -> void:
	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var rear := stage.get_node("RearSpringClickRipple") as Control
	var front := stage.get_node("FrontSpringClickRipple") as Control
	var contact := stage.get_node("PlatformSpringContact") as ColorRect
	assert_almost_eq(rear.position.y, 688.0, 0.01)
	assert_almost_eq(rear.position.y + rear.size.y, 738.0, 0.01)
	assert_almost_eq(contact.position.y + contact.size.y, 842.0, 0.01)
	assert_almost_eq(front.position.y, 842.0, 0.01)
	assert_false(Rect2(rear.position, rear.size).intersects(
			Rect2(Vector2(-32.0, 738.0), Vector2(1984.0, 104.0))))
	assert_false(Rect2(front.position, front.size).intersects(
			Rect2(contact.position, contact.size)))
