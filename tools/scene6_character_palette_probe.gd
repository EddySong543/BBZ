extends SceneTree

const BATTLE6_PATH := "res://src/ui/battle_screen6.tscn"
const HERO_DATA_DIR := "res://assets/data/heroes"
const SAMPLE_STEP := 2


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	(root.get_node("BattleSetup") as Node).call("reset")
	var screen := (load(BATTLE6_PATH) as PackedScene).instantiate()
	root.add_child(screen)
	await process_frame
	var sprite := screen.p1_char_display.get_node(
			"SubViewport/AnimatedSprite2D") as AnimatedSprite2D
	var material := sprite.material as ShaderMaterial
	var passed := material != null \
			and not material.shader.code.contains("TIME") \
			and not material.shader.code.contains("floor(") \
			and not material.shader.code.contains("outside_alpha") \
			and float(material.get_shader_parameter("flash_peak_strength")) == 0.0 \
			and float(material.get_shader_parameter("rim_strength_cap")) == 0.0

	var hero_files := DirAccess.get_files_at(HERO_DATA_DIR)
	hero_files.sort()
	var hero_count := 0
	var frame_count := 0
	var worst_mean_delta := INF
	var worst_identity_ratio := 1.0
	var worst_red_ratio := 0.0
	var worst_luma_shift_span := 0.0
	var worst_color_shift_span := 0.0

	for file_name: String in hero_files:
		if not file_name.begins_with("h") or not file_name.ends_with(".tres"):
			continue
		var hero := load(HERO_DATA_DIR.path_join(file_name)) as HeroData
		if hero == null or hero.sprite_frames_path.is_empty():
			continue
		var frames := load(hero.sprite_frames_path) as SpriteFrames
		if frames == null or not frames.has_animation(&"idle"):
			passed = false
			print("SCENE6_HERO_GRADE: FAIL hero=", file_name,
					" reason=missing_idle_frames")
			continue

		hero_count += 1
		var hero_delta_sum := 0.0
		var hero_sample_count := 0
		var hero_identity_matches := 0
		var hero_identity_samples := 0
		var hero_introduced_red := 0
		var hero_non_red_samples := 0
		var frame_luma_shifts: Array[float] = []
		var frame_color_shifts: Array[float] = []

		for frame_index: int in frames.get_frame_count(&"idle"):
			var texture := frames.get_frame_texture(&"idle", frame_index)
			if texture == null:
				continue
			var image := texture.get_image()
			if image == null or image.is_empty():
				continue
			frame_count += 1
			var frame_luma_shift_sum := 0.0
			var frame_color_shift_sum := 0.0
			var frame_samples := 0
			for y: int in range(0, image.get_height(), SAMPLE_STEP):
				for x: int in range(0, image.get_width(), SAMPLE_STEP):
					var source := image.get_pixel(x, y)
					if source.a < 0.08:
						continue
					var uv := Vector2(
							(float(x) + 0.5) / float(image.get_width()),
							(float(y) + 0.5) / float(image.get_height()))
					var graded := _grade(source, uv, material)
					var color_delta := (
							absf(graded.r - source.r)
							+ absf(graded.g - source.g)
							+ absf(graded.b - source.b)) / 3.0
					var luma_shift := graded.get_luminance() \
							- source.get_luminance()
					hero_delta_sum += color_delta
					hero_sample_count += 1
					frame_color_shift_sum += color_delta
					frame_luma_shift_sum += luma_shift
					frame_samples += 1

					var source_chroma := _chroma(source)
					if source_chroma >= 0.18:
						hero_identity_samples += 1
						if _dominant_channel(source) == _dominant_channel(graded):
							hero_identity_matches += 1
					var source_is_warm := source.r > source.g + 0.05 \
							and source.r > source.b + 0.08
					if not source_is_warm:
						hero_non_red_samples += 1
						if graded.r > graded.g + 0.16 \
								and graded.r > graded.b + 0.18:
							hero_introduced_red += 1
			if frame_samples > 0:
				frame_luma_shifts.append(
						frame_luma_shift_sum / float(frame_samples))
				frame_color_shifts.append(
						frame_color_shift_sum / float(frame_samples))

		var mean_delta := hero_delta_sum / maxf(float(hero_sample_count), 1.0)
		var identity_ratio := float(hero_identity_matches) \
				/ maxf(float(hero_identity_samples), 1.0)
		var introduced_red_ratio := float(hero_introduced_red) \
				/ maxf(float(hero_non_red_samples), 1.0)
		var luma_shift_span := _span(frame_luma_shifts)
		var color_shift_span := _span(frame_color_shifts)
		var hero_passed := hero_sample_count > 0 \
				and mean_delta >= 0.025 \
				and identity_ratio >= 0.90 \
				and introduced_red_ratio <= 0.02 \
				and luma_shift_span <= 0.025 \
				and color_shift_span <= 0.025
		passed = passed and hero_passed
		worst_mean_delta = minf(worst_mean_delta, mean_delta)
		worst_identity_ratio = minf(worst_identity_ratio, identity_ratio)
		worst_red_ratio = maxf(worst_red_ratio, introduced_red_ratio)
		worst_luma_shift_span = maxf(worst_luma_shift_span, luma_shift_span)
		worst_color_shift_span = maxf(worst_color_shift_span, color_shift_span)
		print("SCENE6_HERO_GRADE: ", "PASS" if hero_passed else "FAIL",
				" hero=", file_name.get_basename(),
				" frames=", frame_luma_shifts.size(),
				" mean_delta=", snappedf(mean_delta, 0.001),
				" identity=", snappedf(identity_ratio, 0.001),
				" introduced_red=", snappedf(introduced_red_ratio, 0.001),
				" luma_shift_span=", snappedf(luma_shift_span, 0.001),
				" color_shift_span=", snappedf(color_shift_span, 0.001))

	passed = passed and hero_count >= 24 and frame_count > hero_count
	print("SCENE6_ALL_HERO_GRADE_SUMMARY: ", "PASS" if passed else "FAIL",
			" heroes=", hero_count,
			" idle_frames=", frame_count,
			" min_mean_delta=", snappedf(worst_mean_delta, 0.001),
			" min_identity=", snappedf(worst_identity_ratio, 0.001),
			" max_introduced_red=", snappedf(worst_red_ratio, 0.001),
			" max_luma_shift_span=", snappedf(worst_luma_shift_span, 0.001),
			" max_color_shift_span=", snappedf(worst_color_shift_span, 0.001))
	screen.free()
	quit(0 if passed else 1)


func _grade(source: Color, uv: Vector2, material: ShaderMaterial) -> Color:
	var source_saturation := float(material.get_shader_parameter(
			"source_saturation"))
	var source_contrast := float(material.get_shader_parameter("source_contrast"))
	var scene_exposure := float(material.get_shader_parameter("scene_exposure"))
	var highlight_compression := float(material.get_shader_parameter(
			"highlight_compression"))
	var source_luma := source.get_luminance()
	var color := Color(
			lerpf(source_luma, source.r, source_saturation),
			lerpf(source_luma, source.g, source_saturation),
			lerpf(source_luma, source.b, source_saturation), 1.0)
	color = Color(
			clampf((color.r - 0.5) * source_contrast + 0.5, 0.0, 1.0),
			clampf((color.g - 0.5) * source_contrast + 0.5, 0.0, 1.0),
			clampf((color.b - 0.5) * source_contrast + 0.5, 0.0, 1.0), 1.0)
	color = Color(
			color.r * scene_exposure
					/ (1.0 + color.r * highlight_compression),
			color.g * scene_exposure
					/ (1.0 + color.g * highlight_compression),
			color.b * scene_exposure
					/ (1.0 + color.b * highlight_compression), 1.0)

	var luma := color.get_luminance()
	var scene_shadow: Color = material.get_shader_parameter("scene_grade_shadow")
	var scene_mid: Color = material.get_shader_parameter("scene_grade_mid")
	var scene_high: Color = material.get_shader_parameter("scene_grade_highlight")
	var scene_palette := scene_shadow.lerp(
			scene_mid, smoothstep(0.08, 0.52, luma))
	scene_palette = scene_palette.lerp(
			scene_high, smoothstep(0.46, 0.88, luma))
	var mapped_luma := 0.025 + luma * 0.75
	var graded_luma := lerpf(luma, mapped_luma, float(
			material.get_shader_parameter("scene_value_amount")))
	var scene_target := _match_luma(_multiply_rgb(
			color, scene_palette), graded_luma)
	var identity_weight := clampf(_chroma(color) * 1.5, 0.0, 1.0)
	var grade_weight := float(material.get_shader_parameter("scene_grade_amount")) \
			* lerpf(1.0, float(material.get_shader_parameter(
					"scene_identity_floor")), identity_weight)
	color = color.lerp(scene_target, grade_weight)

	var direction: Vector2 = material.get_shader_parameter("light_dir")
	direction = direction.normalized()
	var form_center: Vector2 = material.get_shader_parameter("form_center")
	var form_roundness: Vector2 = material.get_shader_parameter("form_roundness")
	var form_depth := float(material.get_shader_parameter("form_depth"))
	var form_position := Vector2(
			(uv.x - form_center.x) / maxf(form_roundness.x, 0.001),
			(uv.y - form_center.y) / maxf(form_roundness.y, 0.001))
	var form_normal := Vector3(
			form_position.x, form_position.y, form_depth).normalized()
	var form_light_direction := Vector3(
			direction.x, direction.y, 0.28).normalized()
	var form_facing := smoothstep(
			0.18, 0.82, form_normal.dot(form_light_direction) * 0.5 + 0.5)
	var shadow_mask := 1.0 - form_facing
	var shadow_tint: Color = material.get_shader_parameter("shadow_tint")
	var shadow_hue_amount := float(material.get_shader_parameter(
			"shadow_hue_amount"))
	color = _preserve_luma_tint(
			color, shadow_tint, shadow_hue_amount * shadow_mask)
	var backlight := float(material.get_shader_parameter("backlight"))
	color = _scale_rgb(color, 1.0 - backlight * shadow_mask)

	var bounce_start := float(material.get_shader_parameter("lava_bounce_start"))
	var bounce_softness := float(material.get_shader_parameter(
			"lava_bounce_softness"))
	var bounce_end := minf(bounce_start + bounce_softness, 1.0)
	var lower_body := smoothstep(bounce_start, bounce_end, uv.y)
	var lower_light_direction := Vector3(
			direction.x * 0.30, 1.0, 0.24).normalized()
	var lower_facing := smoothstep(
			0.24, 0.80,
			form_normal.dot(lower_light_direction) * 0.5 + 0.5)
	var bounce_mask := lower_body * (0.45 + lower_facing * 0.55)
	luma = color.get_luminance()
	var bounce_lift := float(material.get_shader_parameter(
			"lava_bounce_luma_lift"))
	var bounce_luma := minf(luma + bounce_lift * (1.0 - luma), 0.82)
	var bounce_color: Color = material.get_shader_parameter("lava_bounce_color")
	var bounce_target := _match_luma(
			_multiply_rgb(color, bounce_color), bounce_luma)
	var bounce_amount := float(material.get_shader_parameter("lava_bounce_amount"))
	return color.lerp(bounce_target, bounce_amount * bounce_mask)


func _scale_rgb(color: Color, amount: float) -> Color:
	return Color(color.r * amount, color.g * amount, color.b * amount, 1.0)


func _multiply_rgb(left: Color, right: Color) -> Color:
	return Color(left.r * right.r, left.g * right.g,
			left.b * right.b, 1.0)


func _preserve_luma_tint(color: Color, tint: Color, amount: float) -> Color:
	return color.lerp(_match_luma(_multiply_rgb(color, tint),
			color.get_luminance()), clampf(amount, 0.0, 1.0))


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


func _chroma(color: Color) -> float:
	return maxf(color.r, maxf(color.g, color.b)) \
			- minf(color.r, minf(color.g, color.b))


func _dominant_channel(color: Color) -> int:
	if color.r >= color.g and color.r >= color.b:
		return 0
	if color.g >= color.b:
		return 1
	return 2


func _span(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var minimum := values[0]
	var maximum := values[0]
	for value: float in values:
		minimum = minf(minimum, value)
		maximum = maxf(maximum, value)
	return maximum - minimum
