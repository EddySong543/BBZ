extends Node

const BATTLE_SCREEN3_PATH := "res://src/ui/battle_screen3.tscn"


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i.ZERO
	BattleSetup.reset()
	var screen := (load(BATTLE_SCREEN3_PATH) as PackedScene).instantiate() as Control
	add_child(screen)
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(screen):
		get_tree().quit(1)
		return

	var stage := screen.get_node("StageSlot/Stage") as BattleStage
	var interaction := stage.get_node("CloudSeaClickDisturbance") as Control
	var easter_egg := stage.get_node("VerticalFishEasterEgg")
	var far_school := stage.get_node("FlyingFishFar") as Scene3FlyingFishSchool
	var near_school := stage.get_node("FlyingFishNear") as Scene3FlyingFishSchool
	var front_cloud := stage.get_node("CloudSeaFront") as Control
	var mid_cloud := stage.get_node("CloudSeaMid") as Control
	var back_cloud := stage.get_node("CloudSeaBack") as Control
	var charge_button := screen.get_node("Buttons/BtnCharge") as Button
	interaction.set("click_cooldown", 0.0)
	var default_fish_probability := float(easter_egg.get("trigger_probability"))
	var default_minimum_clicks := int(easter_egg.get("minimum_clicks_before_roll"))
	var default_fish_cooldown := float(easter_egg.get("retrigger_cooldown"))
	easter_egg.set("trigger_probability", 0.0)
	screen.state = 1  # BattleScreen.State.PLAYER_SELECT
	screen.call("_set_buttons_active", true)
	await get_tree().process_frame

	var button_press_state := {"count": 0}
	charge_button.pressed.connect(
			func() -> void: button_press_state["count"] += 1)
	await _click(charge_button.get_global_rect().get_center())
	var button_kept_priority := (
			int(button_press_state["count"]) == 1
			and int(interaction.call("active_cloud_effect_count")) == 0)

	await _click(Vector2(960.0, 650.0))
	var outside_rejected := int(interaction.call("active_cloud_effect_count")) == 0

	var front_point := front_cloud.get_global_transform_with_canvas() \
			* Vector2(front_cloud.size.x * 0.38, 30.0)
	await _click(front_point)
	var expected_local: Vector2 = (
			interaction.get_global_transform_with_canvas().affine_inverse()
			* front_point)
	var actual_origin: Vector2 = interaction.call("get_last_disturbance_origin")
	var position_followed := absf(actual_origin.x - expected_local.x) <= 4.0
	var front_material := front_cloud.material as ShaderMaterial
	var mid_material := mid_cloud.material as ShaderMaterial
	var back_material := back_cloud.material as ShaderMaterial
	var front_response := (
			StringName(interaction.call("get_active_cloud_layer")) == &"propagating"
			and int(interaction.call("active_cloud_effect_count")) == 1
			and bool(interaction.call("is_cloud_layer_active", &"front"))
			and float(front_material.get_shader_parameter(
					"cloud_press_strength")) > 0.7
			and float(mid_material.get_shader_parameter(
					"cloud_press_strength")) == 0.0
			and float(back_material.get_shader_parameter(
					"cloud_press_strength")) == 0.0)

	await get_tree().create_timer(0.075).timeout
	var front_and_mid := (
			int(interaction.call("active_cloud_effect_count")) == 2
			and bool(interaction.call("is_cloud_layer_active", &"front"))
			and bool(interaction.call("is_cloud_layer_active", &"mid"))
			and float(front_material.get_shader_parameter(
					"cloud_press_strength")) > 0.7
			and float(mid_material.get_shader_parameter(
					"cloud_press_strength")) > 0.44
			and float(back_material.get_shader_parameter(
					"cloud_press_strength")) == 0.0)

	await get_tree().create_timer(0.07).timeout
	var all_layers_propagated := (
			int(interaction.call("active_cloud_effect_count")) == 3
			and bool(interaction.call("is_cloud_layer_active", &"front"))
			and bool(interaction.call("is_cloud_layer_active", &"mid"))
			and bool(interaction.call("is_cloud_layer_active", &"back"))
			and float(front_material.get_shader_parameter(
					"cloud_press_strength")) > 0.7
			and float(mid_material.get_shader_parameter(
					"cloud_press_strength")) > 0.44
			and float(back_material.get_shader_parameter(
					"cloud_press_strength")) > 0.2)
	var probability_readable := (
			default_fish_probability >= 0.04
			and default_fish_probability <= 0.06
			and default_minimum_clicks == 3
			and absf(default_fish_cooldown - 6.0) <= 0.01)
	var automatic_schools_untouched := (
			far_school.get_active_fish_count() == 0
			and near_school.get_active_fish_count() == 0)

	easter_egg.set("trigger_probability", 1.0)
	easter_egg.set("minimum_clicks_before_roll", 1)
	easter_egg.set("retrigger_cooldown", 0.0)
	await _click(front_point)
	await get_tree().create_timer(0.3).timeout
	var active_fish_count := int(easter_egg.call("get_active_fish_count"))
	var vertical_school_active := active_fish_count >= 2 and active_fish_count <= 3
	var fish_reached_mid_sky := float(easter_egg.call(
			"get_highest_active_fish_y")) < 650.0
	await _click(front_point)
	var active_school_not_stacked := (
			int(easter_egg.call("get_active_fish_count")) == active_fish_count)

	await get_tree().create_timer(0.85).timeout
	var first_school_finished := int(easter_egg.call("get_active_fish_count")) == 0
	await _click(front_point)
	await get_tree().create_timer(0.12).timeout
	var reusable_school_active := (
			int(easter_egg.call("get_active_fish_count")) >= 2
			and int(easter_egg.call("get_active_fish_count")) <= 3)
	var fish_reached_high_sky := float(easter_egg.call(
			"get_highest_active_fish_y")) < 830.0

	var passed := (
			button_kept_priority
			and outside_rejected
			and front_response
			and front_and_mid
			and all_layers_propagated
			and position_followed
			and probability_readable
			and vertical_school_active
			and fish_reached_mid_sky
			and active_school_not_stacked
			and first_school_finished
			and reusable_school_active
			and fish_reached_high_sky
			and automatic_schools_untouched)
	print(
			"SCENE3_CLOUD_INTERACTION_PROBE: ",
			"PASS" if passed else "FAIL",
			" button_kept_priority=", button_kept_priority,
			" outside_rejected=", outside_rejected,
			" front_response=", front_response,
			" front_and_mid=", front_and_mid,
			" all_layers_propagated=", all_layers_propagated,
			" position_error=", absf(actual_origin.x - expected_local.x),
			" default_probability=", default_fish_probability,
			" default_minimum_clicks=", default_minimum_clicks,
			" default_cooldown=", default_fish_cooldown,
			" active_fish_count=", active_fish_count,
			" active_school_not_stacked=", active_school_not_stacked,
			" first_school_finished=", first_school_finished,
			" reusable_school_active=", reusable_school_active,
			" fish_mid=", fish_reached_mid_sky,
			" fish_high=", fish_reached_high_sky,
			" automatic_schools_untouched=", automatic_schools_untouched)
	BattleSetup.reset()
	get_tree().quit(0 if passed else 1)


func _click(position: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		event.global_position = position
		Input.parse_input_event(event)
		await get_tree().process_frame
