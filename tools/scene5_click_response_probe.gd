extends Node


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i.ZERO
	BattleSetup.reset()
	var screen := (
			load("res://src/ui/battle_screen5.tscn") as PackedScene
			).instantiate() as Control
	add_child(screen)
	await get_tree().create_timer(1.8).timeout
	if not is_instance_valid(screen):
		get_tree().quit(1)
		return

	var stage := screen.get_node("StageSlot/Stage") as BattleStage
	var wind_field := stage.get_node("WindField")
	var crop_circle := stage.get_node("CropCircle")
	crop_circle.set("trigger_probability", 1.0)
	crop_circle.set("reveal_duration_sec", 0.15)
	crop_circle.set("hold_duration_sec", 0.45)
	crop_circle.set("recover_duration_sec", 0.18)
	var near := stage.get_node("NearWheatLeft") as Control
	var near_material := near.material as ShaderMaterial
	var occluder_material := (
			screen.get_node("WorldGroup/WorldForegroundOccluder") as Control
			).material as ShaderMaterial
	var particle_layers: Array[CPUParticles2D] = [
		stage.get_node("ClickLeavesMidFar") as CPUParticles2D,
		stage.get_node("ClickLeavesFar") as CPUParticles2D,
		stage.get_node("ClickLeavesCover") as CPUParticles2D,
	]
	var click_counts := {"streak": 0, "valid": 0}
	wind_field.far_leaves_triggered.connect(func(_position: Vector2) -> void:
		click_counts["streak"] = int(click_counts["streak"]) + 1)
	wind_field.far_wheat_clicked.connect(func(_position: Vector2) -> void:
		click_counts["valid"] = int(click_counts["valid"]) + 1)

	var near_point := _find_hit_point(wind_field, near, [])
	_click(near_point)
	await get_tree().process_frame
	var near_stays_quiet := int(click_counts["valid"]) == 0 \
			and int(click_counts["streak"]) == 0
	for particles: CPUParticles2D in particle_layers:
		near_stays_quiet = near_stays_quiet and not particles.emitting

	var far_point := Vector2.ZERO
	var far_target: Control = null
	for far_layer_name: String in [
		"FarWheatCoverBack",
		"FarWheat",
		"MidFarWheat",
	]:
		far_target = stage.get_node(far_layer_name) as Control
		far_point = _find_hit_point(
				wind_field,
				far_target,
				[near])
		if far_point != Vector2.ZERO:
			break
	_click(far_point)
	await get_tree().process_frame
	var immediate_cpu_pixels := int(click_counts["streak"]) == 1 \
			and int(click_counts["valid"]) == 1
	for particles: CPUParticles2D in particle_layers:
		immediate_cpu_pixels = immediate_cpu_pixels \
				and particles.emitting \
				and particles.texture != null \
				and particles.texture.get_size() == Vector2(6.0, 3.0) \
				and particles.fixed_fps == 0 \
				and particles.fract_delta \
				and particles.emission_shape \
					== CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	await _wait_real_msec(220)
	_click(far_point + Vector2(24.0, 0.0))
	await get_tree().process_frame
	var repeated_click_did_not_refresh := (
			int(click_counts["valid"]) == 2
			and int(click_counts["streak"]) == 1)
	for offset_x: float in [-18.0, 36.0, 4.0]:
		await _wait_real_msec(220)
		_click(far_point + Vector2(offset_x, 0.0))
		await get_tree().process_frame
	var second_preferred_x := far_point.x + (
			240.0 if far_point.x <= 960.0 else -240.0)
	var second_far_point := _find_hit_point(
			wind_field, far_target, [near], second_preferred_x)
	await _wait_real_msec(220)
	_click(second_far_point)
	await get_tree().process_frame
	var different_place_uses_free_slot := (
			second_far_point != Vector2.ZERO
			and second_far_point.distance_to(far_point) > 160.0
			and int(click_counts["valid"]) == 6
			and int(click_counts["streak"]) == 2
			and int(wind_field.call("get_active_streak_group_count")) >= 2)
	await _wait_real_msec(90)
	var crop_circle_completed := bool(
			crop_circle.call("is_achievement_completed")) \
			and int(crop_circle.call("get_achievement_progress")) == 5 \
			and bool(crop_circle.call("is_visual_active"))
	var last_depth_scale := 0.0
	var shared_crop_center := Vector2.ZERO
	var crop_materials: Array[ShaderMaterial] = []
	for layer_name: String in [
		"MidFarWheat",
		"FarWheat",
		"FarWheatCoverBack",
	]:
		var material := (stage.get_node(layer_name) as CanvasItem).material \
				as ShaderMaterial
		crop_materials.append(material)
		var depth_scale := float(material.get_shader_parameter(
				"crop_circle_depth_scale"))
		var crop_center := material.get_shader_parameter(
				"crop_circle_center") as Vector2
		crop_circle_completed = crop_circle_completed \
				and float(material.get_shader_parameter(
						"crop_circle_strength")) >= 0.95 \
				and float(material.get_shader_parameter(
						"crop_circle_reveal")) >= 0.95 \
				and depth_scale > last_depth_scale \
				and (shared_crop_center == Vector2.ZERO \
						or crop_center == shared_crop_center)
		last_depth_scale = depth_scale
		shared_crop_center = crop_center
	await get_tree().process_frame
	var crop_visible_image := get_viewport().get_texture().get_image()
	for material: ShaderMaterial in crop_materials:
		material.set_shader_parameter("crop_circle_strength", 0.0)
	await get_tree().process_frame
	var crop_hidden_image := get_viewport().get_texture().get_image()
	for material: ShaderMaterial in crop_materials:
		material.set_shader_parameter("crop_circle_strength", 1.0)
	var crop_center_px := Vector2(
			shared_crop_center.x * float(crop_visible_image.get_width()),
			shared_crop_center.y * float(crop_visible_image.get_height()))
	var crop_render_difference := _count_pixel_differences(
			crop_visible_image,
			crop_hidden_image,
			Rect2(crop_center_px - Vector2(720.0, 120.0), Vector2(1440.0, 240.0)))
	var crop_luminance_delta := _average_luminance_delta(
			crop_visible_image,
			crop_hidden_image,
			Rect2(crop_center_px - Vector2(720.0, 120.0), Vector2(1440.0, 240.0)))
	var crop_difference_bounds := _pixel_difference_bounds(
			crop_visible_image,
			crop_hidden_image,
			Rect2(crop_center_px - Vector2(720.0, 120.0), Vector2(1440.0, 240.0)))
	crop_circle_completed = crop_circle_completed \
			and crop_render_difference >= 180 \
			and crop_difference_bounds.size.x >= 720 \
			and crop_luminance_delta >= -0.02
	await _wait_real_msec(560)
	var crop_circle_restored := not bool(crop_circle.call("is_visual_active"))
	for material: ShaderMaterial in crop_materials:
		crop_circle_restored = crop_circle_restored \
				and float(material.get_shader_parameter(
						"crop_circle_strength")) <= 0.01 \
				and float(material.get_shader_parameter(
						"crop_circle_reveal")) <= 0.01

	wind_field.trigger_battle_gust(16.0, 1.0)
	var battle_wind_preserved := (
			float(near_material.get_shader_parameter("gust_strength")) >= 0.95
			and float(occluder_material.get_shader_parameter("gust_strength")) >= 0.95)

	await _wait_real_msec(220)
	var count_before_ui := int(click_counts["valid"])
	var charge_button := screen.get_node("Buttons/BtnCharge") as Button
	_click(charge_button.get_global_rect().get_center())
	await get_tree().process_frame
	var ui_keeps_priority := int(click_counts["valid"]) == count_before_ui

	var passed := (
		near_point != Vector2.ZERO
		and far_point != Vector2.ZERO
		and near_stays_quiet
		and immediate_cpu_pixels
		and repeated_click_did_not_refresh
		and different_place_uses_free_slot
		and crop_circle_completed
		and crop_circle_restored
		and battle_wind_preserved
		and ui_keeps_priority)
	print(
			"SCENE5_CLICK_RESPONSE_PROBE: ",
			"PASS" if passed else "FAIL",
			" near_point=", near_point,
			" far_point=", far_point,
			" second_far_point=", second_far_point,
			" valid_far_clicks=", int(click_counts["valid"]),
			" streak_starts=", int(click_counts["streak"]),
			" near_quiet=", near_stays_quiet,
			" immediate_cpu_pixels=", immediate_cpu_pixels,
			" no_refresh=", repeated_click_did_not_refresh,
			" multi_place=", different_place_uses_free_slot,
			" crop_circle=", crop_circle_completed,
			" crop_restored=", crop_circle_restored,
			" crop_pixels=", crop_render_difference,
			" crop_bounds=", crop_difference_bounds,
			" crop_luma_delta=", crop_luminance_delta,
			" battle_wind=", battle_wind_preserved,
			" ui_keeps_priority=", ui_keeps_priority)
	BattleSetup.reset()
	get_tree().quit(0 if passed else 1)


func _find_hit_point(
		wind_field: Node,
		target: Control,
		excluded: Array[Control],
		preferred_x: float = 960.0) -> Vector2:
	for radius: int in range(0, 80):
		for side: float in [-1.0, 1.0]:
			for y: int in range(180, 1040, 12):
				var x := clampf(
						preferred_x + side * float(radius * 12), 20.0, 1900.0)
				var point := Vector2(x, float(y))
				if not bool(wind_field.call("_texture_hit", target, point)):
					continue
				var blocked := false
				for layer: Control in excluded:
					if bool(wind_field.call("_texture_hit", layer, point)):
						blocked = true
						break
				if not blocked:
					return point
	return Vector2.ZERO


func _wait_real_msec(duration_msec: int) -> void:
	var deadline := Time.get_ticks_msec() + duration_msec
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _count_pixel_differences(
		first: Image,
		second: Image,
		region: Rect2) -> int:
	var image_bounds := Rect2i(Vector2i.ZERO, first.get_size())
	var sample_bounds := Rect2i(
			Vector2i(region.position.floor()),
			Vector2i(region.size.ceil())).intersection(image_bounds)
	var changed := 0
	for y: int in range(sample_bounds.position.y, sample_bounds.end.y, 2):
		for x: int in range(sample_bounds.position.x, sample_bounds.end.x, 2):
			var first_color := first.get_pixel(x, y)
			var second_color := second.get_pixel(x, y)
			var difference := maxf(
					absf(first_color.r - second_color.r),
					maxf(
							absf(first_color.g - second_color.g),
							absf(first_color.b - second_color.b)))
			if difference >= 0.045:
				changed += 1
	return changed


func _average_luminance_delta(
		visible_image: Image,
		hidden_image: Image,
		region: Rect2) -> float:
	var image_bounds := Rect2i(Vector2i.ZERO, visible_image.get_size())
	var sample_bounds := Rect2i(
			Vector2i(region.position.floor()),
			Vector2i(region.size.ceil())).intersection(image_bounds)
	var total_delta := 0.0
	var sample_count := 0
	for y: int in range(sample_bounds.position.y, sample_bounds.end.y, 2):
		for x: int in range(sample_bounds.position.x, sample_bounds.end.x, 2):
			var visible_color := visible_image.get_pixel(x, y)
			var hidden_color := hidden_image.get_pixel(x, y)
			var visible_luminance := visible_color.r * 0.2126 \
					+ visible_color.g * 0.7152 + visible_color.b * 0.0722
			var hidden_luminance := hidden_color.r * 0.2126 \
					+ hidden_color.g * 0.7152 + hidden_color.b * 0.0722
			total_delta += visible_luminance - hidden_luminance
			sample_count += 1
	return total_delta / float(maxi(sample_count, 1))


func _pixel_difference_bounds(
		first: Image,
		second: Image,
		region: Rect2) -> Rect2i:
	var image_bounds := Rect2i(Vector2i.ZERO, first.get_size())
	var sample_bounds := Rect2i(
			Vector2i(region.position.floor()),
			Vector2i(region.size.ceil())).intersection(image_bounds)
	var minimum := sample_bounds.end
	var maximum := sample_bounds.position
	var found := false
	for y: int in range(sample_bounds.position.y, sample_bounds.end.y, 2):
		for x: int in range(sample_bounds.position.x, sample_bounds.end.x, 2):
			var first_color := first.get_pixel(x, y)
			var second_color := second.get_pixel(x, y)
			var difference := maxf(
					absf(first_color.r - second_color.r),
					maxf(
							absf(first_color.g - second_color.g),
							absf(first_color.b - second_color.b)))
			if difference < 0.03:
				continue
			found = true
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	return Rect2i(minimum, maximum - minimum) if found else Rect2i()


func _click(position: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		event.global_position = position
		Input.parse_input_event(event)
