extends Node

const BATTLE_SCREEN2_PATH := "res://src/ui/battle_screen2.tscn"


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i.ZERO
	BattleSetup.reset()
	var screen := (load(BATTLE_SCREEN2_PATH) as PackedScene).instantiate() as Control
	add_child(screen)
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(screen):
		get_tree().quit(1)
		return

	var stage := screen.get_node("StageSlot/Stage") as BattleStage
	var waterfall := stage.get_node("Waterfall") as Control
	var river := stage.get_node("River") as Control
	var splash := stage.get_node("WaterfallClickSplash")
	var ripple := stage.get_node("RiverClickRipple")
	var fish := stage.get_node("WaterfallFishLeap")
	fish.set("trigger_clicks", 3)
	fish.set("trigger_chance", 1.0)
	fish.set("pity_clicks", 7)
	fish.set("retrigger_cooldown", 0.0)
	var charge_button := screen.get_node("Buttons/BtnCharge") as Button
	screen.state = 1  # BattleScreen.State.PLAYER_SELECT
	screen.call("_set_buttons_active", true)
	await get_tree().process_frame
	var button_press_state := {"count": 0}
	charge_button.pressed.connect(func() -> void: button_press_state["count"] += 1)

	var water_count_before_button := int(splash.call("active_effect_count")) \
			+ int(ripple.call("active_effect_count"))
	await _click(charge_button.get_global_rect().get_center())
	var water_count_after_button := int(splash.call("active_effect_count")) \
			+ int(ripple.call("active_effect_count"))
	var button_click_did_not_reach_water := \
			water_count_after_button == water_count_before_button
	var button_keeps_input_priority := \
			charge_button.mouse_filter == Control.MOUSE_FILTER_STOP

	var waterfall_point := waterfall.get_global_transform_with_canvas() \
			* Vector2(360.0, 420.0)
	await _click(waterfall_point)
	var splash_spawned := int(splash.call("active_effect_count")) == 1
	var ripple_still_clear := int(ripple.call("active_effect_count")) == 0
	var fish_waited_for_multiple_clicks := int(fish.call("active_fish_count")) == 0

	var river_point := river.get_global_transform_with_canvas() \
			* Vector2(river.size.x * 0.5, 16.0)
	await _click(river_point)
	var ripple_spawned := int(ripple.call("active_effect_count")) == 1

	await get_tree().create_timer(0.13).timeout
	await _click(waterfall_point)
	await get_tree().create_timer(0.13).timeout
	await _click(waterfall_point)
	var fish_spawned := int(fish.call("active_fish_count")) == 1
	var normal_fish_drop := float(fish.call("fish_vertical_drop"))
	var fish_has_drop := normal_fish_drop > 240.0
	var expected_fish_start: Vector2 = fish.get_global_transform_with_canvas().affine_inverse() \
			* waterfall_point
	var fish_pixel_size := float(fish.get("pixel_size"))
	expected_fish_start = (expected_fish_start / fish_pixel_size).round() * fish_pixel_size
	var fish_starts_at_click := (fish.call("fish_start_position") as Vector2) \
			.distance_to(expected_fish_start) <= 0.01

	await get_tree().create_timer(1.3).timeout
	fish.set("trigger_clicks", 2)
	fish.set("golden_fish_chance", 1.0)
	var middle_waterfall_point := waterfall.get_global_transform_with_canvas() \
			* Vector2(360.0, 620.0)
	await _click(middle_waterfall_point)
	await get_tree().create_timer(0.13).timeout
	await _click(middle_waterfall_point)
	var golden_fish_spawned := bool(fish.call("is_golden_fish_active"))
	var golden_fish_swims_upstream := float(fish.call("fish_vertical_drop")) < -240.0

	var passed := (
			int(button_press_state["count"]) == 1
			and button_click_did_not_reach_water
			and button_keeps_input_priority
			and splash_spawned
			and ripple_still_clear
			and ripple_spawned
			and fish_waited_for_multiple_clicks
			and fish_spawned
			and fish_has_drop
			and fish_starts_at_click
			and golden_fish_spawned
			and golden_fish_swims_upstream)
	print(
			"SCENE2_WATER_INTERACTION_PROBE: ",
			"PASS" if passed else "FAIL",
			" button_press_count=", int(button_press_state["count"]),
			" button_water_delta=", water_count_after_button - water_count_before_button,
			" button_keeps_input_priority=", button_keeps_input_priority,
			" splash_spawned=", splash_spawned,
			" ripple_still_clear=", ripple_still_clear,
			" ripple_spawned=", ripple_spawned,
			" fish_waited=", fish_waited_for_multiple_clicks,
			" fish_spawned=", fish_spawned,
			" normal_fish_drop=", normal_fish_drop,
			" fish_starts_at_click=", fish_starts_at_click,
			" golden_fish_spawned=", golden_fish_spawned,
			" golden_fish_drop=", float(fish.call("fish_vertical_drop")),
			" golden_fish_swims_upstream=", golden_fish_swims_upstream)
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
