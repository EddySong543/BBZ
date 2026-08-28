extends SceneTree

const BATTLE8_PATH := "res://src/ui/battle_screen8.tscn"
const CHARACTER_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene8_character_light.gdshader")
const HERO_DATA_DIR := "res://assets/data/heroes"
const SAMPLE_STEP := 3


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	(root.get_node("BattleSetup") as Node).call("reset")
	var screen := (load(BATTLE8_PATH) as PackedScene).instantiate()
	root.add_child(screen)
	await process_frame
	var p1_sprite := screen.p1_char_display.get_node(
			"SubViewport/AnimatedSprite2D") as AnimatedSprite2D
	var p2_sprite := screen.p2_char_display.get_node(
			"SubViewport/AnimatedSprite2D") as AnimatedSprite2D
	var material := p1_sprite.material as ShaderMaterial
	var p2_material := p2_sprite.material as ShaderMaterial
	var binding_passed := (
			material != null and p2_material != null
			and material != p2_material
			and material.resource_local_to_scene
			and p2_material.resource_local_to_scene
			and material.shader.resource_path == CHARACTER_SHADER_PATH
			and p2_material.shader.resource_path == CHARACTER_SHADER_PATH
			and not material.shader.code.contains("floor(")
			and float(material.get_shader_parameter("aurora_cycle_sec")) >= 24.0)

	var hero_files := DirAccess.get_files_at(HERO_DATA_DIR)
	hero_files.sort()
	var hero_count := 0
	var frame_count := 0
	var passed := binding_passed
	var minimum_identity := 1.0
	var minimum_color_delta := INF
	var maximum_color_delta := 0.0
	var minimum_cool_gain := INF
	var minimum_violet_gain := INF
	var maximum_phase_luma_delta := 0.0
	var maximum_phase_color_delta := 0.0
	var maximum_frame_luma_span := 0.0

	for file_name: String in hero_files:
		if not file_name.begins_with("h") or not file_name.ends_with(".tres"):
			continue
		var hero := load(HERO_DATA_DIR.path_join(file_name)) as HeroData
		if hero == null or hero.sprite_frames_path.is_empty():
			continue
		var frames := load(hero.sprite_frames_path) as SpriteFrames
		if frames == null or not frames.has_animation(&"idle"):
			passed = false
			continue

		hero_count += 1
		var samples := 0
		var color_delta_sum := 0.0
		var luma_shift_sum := 0.0
		var identity_samples := 0
		var identity_similarity_sum := 0.0
		var upper_samples := 0
		var upper_cool_gain_sum := 0.0
		var lower_samples := 0
		var lower_violet_gain_sum := 0.0
		var phase_luma_delta_sum := 0.0
		var phase_color_delta_sum := 0.0
		var frame_luma_shifts: Array[float] = []

		for frame_index: int in frames.get_frame_count(&"idle"):
			var texture := frames.get_frame_texture(&"idle", frame_index)
			if texture == null:
				continue
			var image := texture.get_image()
			if image == null or image.is_empty():
				continue
			frame_count += 1
			var frame_shift_sum := 0.0
			var frame_samples := 0
			for y: int in range(0, image.get_height(), SAMPLE_STEP):
				for x: int in range(0, image.get_width(), SAMPLE_STEP):
					var source := image.get_pixel(x, y)
					if source.a < 0.08:
						continue
					var uv := Vector2(
							(float(x) + 0.5) / float(image.get_width()),
							(float(y) + 0.5) / float(image.get_height()))
					var low_phase := _grade(source, uv, material, 0.0)
					var high_phase := _grade(source, uv, material, 1.0)
					var graded := _mix_rgb(low_phase, high_phase, 0.5)
					var color_delta := _color_delta(source, graded)
					var luma_shift := graded.get_luminance() - source.get_luminance()
					color_delta_sum += color_delta
					luma_shift_sum += luma_shift
					frame_shift_sum += luma_shift
					phase_luma_delta_sum += absf(
							high_phase.get_luminance() - low_phase.get_luminance())
					phase_color_delta_sum += _color_delta(low_phase, high_phase)
					samples += 1
					frame_samples += 1
					if _chroma(source) >= 0.18:
						identity_samples += 1
						var hue_similarity := _hue_similarity(source, graded)
						identity_similarity_sum += hue_similarity
					if uv.y <= 0.55:
						upper_samples += 1
						upper_cool_gain_sum += _cool_bias(graded) - _cool_bias(source)
					if uv.y >= 0.65:
						lower_samples += 1
						lower_violet_gain_sum += (
								graded.b - graded.g - source.b + source.g)
			if frame_samples > 0:
				frame_luma_shifts.append(
						frame_shift_sum / float(frame_samples))

		var mean_delta := color_delta_sum / maxf(float(samples), 1.0)
		var mean_luma_shift := luma_shift_sum / maxf(float(samples), 1.0)
		var identity_ratio := identity_similarity_sum \
				/ maxf(float(identity_samples), 1.0)
		var cool_gain := upper_cool_gain_sum / maxf(float(upper_samples), 1.0)
		var violet_gain := lower_violet_gain_sum / maxf(float(lower_samples), 1.0)
		var phase_luma_delta := phase_luma_delta_sum / maxf(float(samples), 1.0)
		var phase_color_delta := phase_color_delta_sum / maxf(float(samples), 1.0)
		var frame_luma_span := _span(frame_luma_shifts)
		var hero_passed := (
				samples > 0
				and mean_delta >= 0.025 and mean_delta <= 0.18
				and mean_luma_shift >= -0.16 and mean_luma_shift <= -0.005
				and identity_ratio >= 0.78
				and cool_gain >= 0.006
				and violet_gain >= 0.001
				and phase_luma_delta <= 0.008
				and phase_color_delta >= 0.0005
				and phase_color_delta <= 0.035
				and frame_luma_span <= 0.035)
		passed = passed and hero_passed
		minimum_identity = minf(minimum_identity, identity_ratio)
		minimum_color_delta = minf(minimum_color_delta, mean_delta)
		maximum_color_delta = maxf(maximum_color_delta, mean_delta)
		minimum_cool_gain = minf(minimum_cool_gain, cool_gain)
		minimum_violet_gain = minf(minimum_violet_gain, violet_gain)
		maximum_phase_luma_delta = maxf(
				maximum_phase_luma_delta, phase_luma_delta)
		maximum_phase_color_delta = maxf(
				maximum_phase_color_delta, phase_color_delta)
		maximum_frame_luma_span = maxf(
				maximum_frame_luma_span, frame_luma_span)
		print(
				"SCENE8_HERO_AURORA_GRADE: ", "PASS" if hero_passed else "FAIL",
				" hero=", file_name.get_basename(),
				" frames=", frame_luma_shifts.size(),
				" delta=", snappedf(mean_delta, 0.001),
				" luma_shift=", snappedf(mean_luma_shift, 0.001),
				" identity=", snappedf(identity_ratio, 0.001),
				" cool_gain=", snappedf(cool_gain, 0.001),
				" violet_gain=", snappedf(violet_gain, 0.001),
				" phase_luma=", snappedf(phase_luma_delta, 0.001),
				" phase_color=", snappedf(phase_color_delta, 0.001),
				" frame_span=", snappedf(frame_luma_span, 0.001))

	passed = passed and hero_count >= 24 and frame_count > hero_count
	print(
			"SCENE8_CHARACTER_GRADE_PROBE: ", "PASS" if passed else "FAIL",
			" binding=", binding_passed,
			" heroes=", hero_count,
			" idle_frames=", frame_count,
			" min_identity=", snappedf(minimum_identity, 0.001),
			" delta_range=", Vector2(
					snappedf(minimum_color_delta, 0.001),
					snappedf(maximum_color_delta, 0.001)),
			" min_cool_gain=", snappedf(minimum_cool_gain, 0.001),
			" min_violet_gain=", snappedf(minimum_violet_gain, 0.001),
			" max_phase_luma=", snappedf(maximum_phase_luma_delta, 0.001),
			" max_phase_color=", snappedf(maximum_phase_color_delta, 0.001),
			" max_frame_span=", snappedf(maximum_frame_luma_span, 0.001))
	screen.free()
	(root.get_node("BattleSetup") as Node).call("reset")
	quit(0 if passed else 1)


func _grade(
		source: Color,
		uv: Vector2,
		material: ShaderMaterial,
		aurora_phase: float) -> Color:
	var source_luma := source.get_luminance()
	var identity_weight := clampf(_chroma(source) * 3.0, 0.0, 1.0)
	var source_saturation := float(material.get_shader_parameter(
			"source_saturation"))
	var color := Color(source_luma, source_luma, source_luma, 1.0).lerp(
			source, source_saturation)
	var contrast := float(material.get_shader_parameter("source_contrast"))
	color = Color(
			clampf((color.r - 0.5) * contrast + 0.5, 0.0, 1.0),
			clampf((color.g - 0.5) * contrast + 0.5, 0.0, 1.0),
			clampf((color.b - 0.5) * contrast + 0.5, 0.0, 1.0), 1.0)
	var exposure := float(material.get_shader_parameter("scene_exposure"))
	var compression := float(material.get_shader_parameter(
			"highlight_compression"))
	color = Color(
			color.r * exposure / (1.0 + color.r * compression),
			color.g * exposure / (1.0 + color.g * compression),
			color.b * exposure / (1.0 + color.b * compression), 1.0)

	var luma := color.get_luminance()
	var night_shadow: Color = material.get_shader_parameter("night_shadow_color")
	var night_mid: Color = material.get_shader_parameter("night_mid_color")
	var night_palette := night_shadow.lerp(
			night_mid, smoothstep(0.12, 0.76, luma))
	var night_amount := float(material.get_shader_parameter("night_grade_amount"))
	var night_weight := night_amount * lerpf(
			1.0,
			float(material.get_shader_parameter("scene_identity_floor")),
			identity_weight)
	color = _preserve_luma_tint(color, night_palette, night_weight)
	color = _scale_rgb(color, lerpf(
			1.0,
			float(material.get_shader_parameter("night_value_scale")),
			night_amount))

	var direction: Vector2 = material.get_shader_parameter("light_dir")
	direction = direction.normalized()
	var directional_sample := (uv - Vector2(0.5, 0.5)).dot(direction)
	var light_side := smoothstep(-0.28, 0.34, directional_sample)
	var shadow_side := 1.0 - smoothstep(-0.34, 0.04, directional_sample)
	var shadow_tint: Color = material.get_shader_parameter("shadow_tint")
	var backlight := float(material.get_shader_parameter("backlight"))
	color = _preserve_luma_tint(
			color, shadow_tint, backlight * shadow_side)
	color = _scale_rgb(color, 1.0 - backlight * shadow_side * 0.16)
	var skin_warmth: Color = material.get_shader_parameter("skin_warmth")
	color = color.lerp(
			_multiply_rgb(color, skin_warmth),
			float(material.get_shader_parameter("warmth_amount")))

	var current_luma := color.get_luminance()
	var dark_protection := 1.0 - current_luma * 0.72
	var fill_color: Color = material.get_shader_parameter("fill_color")
	var fill_amount := float(material.get_shader_parameter("fill_amount"))
	color = _add_rgb(color, _scale_rgb(
			fill_color,
			fill_amount * (0.58 + light_side * 0.22) * dark_protection))

	var flow_offset := (aurora_phase - 0.5) \
			* float(material.get_shader_parameter("aurora_flow_amount")) * 2.0
	var facing_axis := Vector2(direction.x, 0.18).normalized()
	var aurora_mix := clampf(
			0.50 + (uv - Vector2(0.5, 0.5)).dot(facing_axis) * 0.34 + flow_offset,
			0.0, 1.0)
	var aurora_green: Color = material.get_shader_parameter("aurora_green")
	var aurora_cyan: Color = material.get_shader_parameter("aurora_cyan")
	var aurora_palette := aurora_green.lerp(aurora_cyan, aurora_mix)
	var upper_body := 1.0 - smoothstep(0.16, 0.88, uv.y)
	var key_mask := light_side * (0.58 + upper_body * 0.42)
	current_luma = color.get_luminance()
	var key_luma := minf(
			current_luma + float(material.get_shader_parameter(
					"aurora_key_luma_lift")) * (1.0 - current_luma),
			0.78)
	var key_target := _match_luma(
			_multiply_rgb(color, aurora_palette), key_luma)
	color = color.lerp(
			key_target,
			float(material.get_shader_parameter("aurora_key_amount"))
					* key_mask
					* lerpf(1.0, 0.30, identity_weight))

	var lower_body := smoothstep(
			float(material.get_shader_parameter("violet_bounce_start")),
			0.96, uv.y)
	var bounce_mask := lower_body * (0.58 + shadow_side * 0.42)
	var violet: Color = material.get_shader_parameter("aurora_violet")
	current_luma = color.get_luminance()
	var violet_target := _match_luma(
			_multiply_rgb(color, violet),
			minf(current_luma + 0.018 * (1.0 - current_luma), 0.68))
	color = color.lerp(
			violet_target,
			float(material.get_shader_parameter("violet_bounce_amount"))
					* bounce_mask
					* lerpf(1.0, 0.42, identity_weight))
	var warm_source := smoothstep(
			0.035, 0.16, source.r - maxf(source.g, source.b))
	var bright_source := smoothstep(0.42, 0.76, source_luma)
	var warm_identity_mask := warm_source * bright_source
	var warm_identity_target := _match_luma(
			source, color.get_luminance())
	return color.lerp(
			warm_identity_target,
			float(material.get_shader_parameter("warm_identity_protection"))
					* warm_identity_mask)


func _match_luma(tint: Color, reference_luma: float) -> Color:
	var multiplier := reference_luma / maxf(tint.get_luminance(), 0.001)
	var matched := Color(
			clampf(tint.r * multiplier, 0.0, 1.0),
			clampf(tint.g * multiplier, 0.0, 1.0),
			clampf(tint.b * multiplier, 0.0, 1.0), 1.0)
	var correction := reference_luma - matched.get_luminance()
	return Color(
			clampf(matched.r + correction, 0.0, 1.0),
			clampf(matched.g + correction, 0.0, 1.0),
			clampf(matched.b + correction, 0.0, 1.0), 1.0)


func _preserve_luma_tint(color: Color, tint: Color, amount: float) -> Color:
	return color.lerp(
			_match_luma(_multiply_rgb(color, tint), color.get_luminance()),
			clampf(amount, 0.0, 1.0))


func _multiply_rgb(left: Color, right: Color) -> Color:
	return Color(left.r * right.r, left.g * right.g, left.b * right.b, 1.0)


func _scale_rgb(color: Color, amount: float) -> Color:
	return Color(color.r * amount, color.g * amount, color.b * amount, 1.0)


func _add_rgb(left: Color, right: Color) -> Color:
	return Color(
			clampf(left.r + right.r, 0.0, 1.0),
			clampf(left.g + right.g, 0.0, 1.0),
			clampf(left.b + right.b, 0.0, 1.0), 1.0)


func _mix_rgb(left: Color, right: Color, amount: float) -> Color:
	return Color(
			lerpf(left.r, right.r, amount),
			lerpf(left.g, right.g, amount),
			lerpf(left.b, right.b, amount), 1.0)


func _color_delta(left: Color, right: Color) -> float:
	return (absf(left.r - right.r) + absf(left.g - right.g)
			+ absf(left.b - right.b)) / 3.0


func _cool_bias(color: Color) -> float:
	return (color.g + color.b) * 0.5 - color.r


func _chroma(color: Color) -> float:
	return maxf(color.r, maxf(color.g, color.b)) \
			- minf(color.r, minf(color.g, color.b))


func _hue_similarity(left: Color, right: Color) -> float:
	var left_minimum := minf(left.r, minf(left.g, left.b))
	var right_minimum := minf(right.r, minf(right.g, right.b))
	var left_axis := Vector3(
			left.r - left_minimum,
			left.g - left_minimum,
			left.b - left_minimum).normalized()
	var right_axis := Vector3(
			right.r - right_minimum,
			right.g - right_minimum,
			right.b - right_minimum).normalized()
	return clampf(left_axis.dot(right_axis), 0.0, 1.0)


func _span(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var minimum := values[0]
	var maximum := values[0]
	for value: float in values:
		minimum = minf(minimum, value)
		maximum = maxf(maximum, value)
	return maximum - minimum
