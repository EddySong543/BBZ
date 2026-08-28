extends SceneTree

const BATTLE5_PATH := "res://src/ui/battle_screen5.tscn"
const CHARACTER_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene5_character_light.gdshader")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	(root.get_node("BattleSetup") as Node).call("reset")
	var screen := (load(BATTLE5_PATH) as PackedScene).instantiate()
	root.add_child(screen)
	await process_frame

	var passed := true
	var materials: Array[ShaderMaterial] = []
	for display_name: String in ["P1CharDisplay", "P2CharDisplay"]:
		var display := screen.get_node("WorldGroup/%s" % display_name) \
				as CharacterDisplay
		var sprite := display.get_node("SubViewport/AnimatedSprite2D") \
				as AnimatedSprite2D
		var material := sprite.material as ShaderMaterial
		materials.append(material)
		var frame_texture := sprite.sprite_frames.get_frame_texture(
				sprite.animation, sprite.frame)
		var source_image := frame_texture.get_image()
		var graded_image := _grade_image(source_image, material)
		var source_stats := _visible_stats(source_image)
		var rendered_stats := _visible_stats(graded_image)
		var sunlight_chroma_bias := _directional_warm_bias(
				source_image, graded_image, material)
		var shadow_chroma_bias := _directional_shadow_cool_bias(
				source_image, graded_image, material)
		var bright_facing_luma_lift := _bright_facing_luma_lift(
				source_image, graded_image, material)
		var temporal_stats := _animation_temporal_stats(sprite, material)
		var idle_cycle_stats := _idle_cycle_stats(source_image, material)
		var frame_passed := (
				material != null
				and material.shader.resource_path == CHARACTER_SHADER_PATH
				and rendered_stats.x >= source_stats.x - 0.08
				and rendered_stats.x <= source_stats.x + 0.025
				and rendered_stats.y >= source_stats.y - 0.015
				and rendered_stats.y <= source_stats.y + 0.09
				and rendered_stats.z >= source_stats.z - 0.08
				and rendered_stats.w <= source_stats.w + 0.02
				and sunlight_chroma_bias >= -0.005
				and sunlight_chroma_bias <= 0.07
				and shadow_chroma_bias >= -0.03
				and shadow_chroma_bias <= 0.03
				and bright_facing_luma_lift <= 0.015
				and temporal_stats.x <= 0.01
				and temporal_stats.y <= 0.12
				and temporal_stats.z <= 0.02
				and temporal_stats.w <= 0.015
				and idle_cycle_stats.x >= 0.008
				and idle_cycle_stats.x <= 0.02
				and absf(idle_cycle_stats.y) <= 0.003)
		passed = passed and frame_passed
		print(
				"SCENE5_CHARACTER_GRADE_LAYER: ",
				"PASS" if frame_passed else "FAIL",
				" display=", display_name,
				" source_luma=", snappedf(source_stats.x, 0.001),
				" rendered_luma=", snappedf(rendered_stats.x, 0.001),
				" source_saturation=", snappedf(source_stats.y, 0.001),
				" rendered_saturation=", snappedf(rendered_stats.y, 0.001),
				" source_dark_fraction=", snappedf(source_stats.z, 0.001),
				" rendered_dark_fraction=", snappedf(rendered_stats.z, 0.001),
				" source_bright_fraction=", snappedf(source_stats.w, 0.001),
				" rendered_bright_fraction=", snappedf(rendered_stats.w, 0.001),
				" sunlight_chroma_bias=", snappedf(sunlight_chroma_bias, 0.001),
				" shadow_chroma_bias=", snappedf(shadow_chroma_bias, 0.001),
				" bright_facing_luma_lift=",
				snappedf(bright_facing_luma_lift, 0.001),
				" max_introduced_blue_fraction=", snappedf(temporal_stats.x, 0.001),
				" max_introduced_gold_fraction=", snappedf(temporal_stats.y, 0.001),
				" frame_chroma_delta_span=", snappedf(temporal_stats.z, 0.001),
				" frame_luma_span=", snappedf(temporal_stats.w, 0.001),
				" idle_luma_span=", snappedf(idle_cycle_stats.x, 0.001),
				" idle_hue_shift=", snappedf(idle_cycle_stats.y, 0.001))
	passed = passed and materials.size() == 2 and materials[0] != materials[1]
	if materials.size() == 2:
		var p1_direction: Vector2 = materials[0].get_shader_parameter("light_dir")
		var p2_direction: Vector2 = materials[1].get_shader_parameter("light_dir")
		passed = passed \
				and p1_direction.x > 0.0 \
				and p2_direction.x < 0.0 \
				and is_equal_approx(p1_direction.y, p2_direction.y)
	print("SCENE5_CHARACTER_GRADE_PROBE: ", "PASS" if passed else "FAIL")
	screen.free()
	quit(0 if passed else 1)


func _grade_image(
		image: Image,
		material: ShaderMaterial,
		idle_envelope: float = 0.5) -> Image:
	var graded := image.duplicate()
	var source_saturation := float(material.get_shader_parameter(
			"source_saturation"))
	var source_contrast := float(material.get_shader_parameter("source_contrast"))
	var scene_exposure := float(material.get_shader_parameter("scene_exposure"))
	var highlight_compression := float(material.get_shader_parameter(
			"highlight_compression"))
	var light_dir: Vector2 = material.get_shader_parameter("light_dir")
	light_dir = light_dir.normalized()
	var backlight := float(material.get_shader_parameter("backlight"))
	var shadow_tint: Color = material.get_shader_parameter("shadow_tint")
	var skin_warmth: Color = material.get_shader_parameter("skin_warmth")
	var warmth_amount := float(material.get_shader_parameter("warmth_amount"))
	var fill_color: Color = material.get_shader_parameter("fill_color")
	var fill_amount := float(material.get_shader_parameter("fill_amount"))
	var sun_key_color: Color = material.get_shader_parameter("sun_key_color")
	var sun_key_amount := float(material.get_shader_parameter("sun_key_amount"))
	var sun_warm_shift: Vector3 = material.get_shader_parameter("sun_warm_shift")
	var sky_ambient_color: Color = material.get_shader_parameter("sky_ambient_color")
	var sky_ambient_amount := float(material.get_shader_parameter("sky_ambient_amount"))
	var field_bounce_color: Color = material.get_shader_parameter("field_bounce_color")
	var field_bounce_amount := float(material.get_shader_parameter("field_bounce_amount"))
	var field_bounce_start := float(material.get_shader_parameter("field_bounce_start"))
	var rim_color: Color = material.get_shader_parameter("rim_color")
	var rim_strength := float(material.get_shader_parameter("rim_strength"))
	var rim_width := float(material.get_shader_parameter("rim_width"))
	var idle_light_amount := float(material.get_shader_parameter(
			"idle_light_amount"))
	for y: int in range(graded.get_height()):
		for x: int in range(graded.get_width()):
			var source: Color = graded.get_pixel(x, y)
			if source.a <= 0.05:
				continue
			var uv := Vector2(
					(float(x) + 0.5) / float(graded.get_width()),
					(float(y) + 0.5) / float(graded.get_height()))
			var source_luma := source.get_luminance()
			var color := Color(
					lerpf(source_luma, source.r, source_saturation),
					lerpf(source_luma, source.g, source_saturation),
					lerpf(source_luma, source.b, source_saturation),
					source.a)
			color = Color(
					clampf((color.r - 0.5) * source_contrast + 0.5, 0.0, 1.0),
					clampf((color.g - 0.5) * source_contrast + 0.5, 0.0, 1.0),
					clampf((color.b - 0.5) * source_contrast + 0.5, 0.0, 1.0),
					color.a)
			color = Color(
					color.r * scene_exposure / (1.0 + color.r * highlight_compression),
					color.g * scene_exposure / (1.0 + color.g * highlight_compression),
					color.b * scene_exposure / (1.0 + color.b * highlight_compression),
					color.a)
			var directional_sample := (uv - Vector2(0.5, 0.5)).dot(light_dir)
			var shadow_band := 1.0 \
					- smoothstep(-0.34, 0.02, directional_sample)
			var sun_band := smoothstep(0.10, 0.38, directional_sample)
			var base_luma := color.get_luminance()
			var shadow_palette_target := _luma_preserving_palette(
					shadow_tint, minf(base_luma * 0.93, 0.52))
			color = color.lerp(
					shadow_palette_target,
					backlight * shadow_band)
			color = color.lerp(Color(
					color.r * skin_warmth.r,
					color.g * skin_warmth.g,
					color.b * skin_warmth.b,
					color.a), warmth_amount)
			var luma := color.get_luminance()
			var dark_protection := 1.0 - luma * 0.72
			var sky_mask := (0.55 + (1.0 - luma) * 0.45) \
					* shadow_band
			color = color.lerp(Color(
					color.r * sky_ambient_color.r,
					color.g * sky_ambient_color.g,
					color.b * sky_ambient_color.b,
					color.a), sky_ambient_amount * sky_mask)
			color.r += fill_color.r * fill_amount \
					* (0.62 + shadow_band * 0.18) * dark_protection
			color.g += fill_color.g * fill_amount \
					* (0.62 + shadow_band * 0.18) * dark_protection
			color.b += fill_color.b * fill_amount \
					* (0.62 + shadow_band * 0.18) * dark_protection
			var upper_key := 1.0 - smoothstep(0.08, 0.9, uv.y)
			var sun_highlight_guard := 1.0 \
					- smoothstep(0.38, 0.72, luma) * 0.72
			var sun_target_luma := minf(
					luma + 0.025 * dark_protection * sun_highlight_guard,
					0.58)
			var source_warm_target := Color(
					color.r * sun_warm_shift.x,
					color.g * sun_warm_shift.y,
					color.b * sun_warm_shift.z,
					color.a).clamp()
			var sun_palette_target := _luma_preserving_palette(
					sun_key_color, sun_target_luma)
			sun_palette_target = source_warm_target.lerp(
					sun_palette_target, 0.24)
			var sun_weight := sun_key_amount * sun_band \
					* (0.72 + upper_key * 0.28)
			color = color.lerp(sun_palette_target, sun_weight)
			var field_bounce := smoothstep(field_bounce_start, 1.0, uv.y)
			var field_palette_target := _luma_preserving_palette(
					field_bounce_color,
					minf(color.get_luminance() + 0.012, 0.48))
			var field_weight := field_bounce_amount * field_bounce \
					* (1.0 - sun_band * 0.35)
			color = color.lerp(field_palette_target, field_weight)
			var rim_x := clampi(
					roundi(float(x) + light_dir.x * rim_width),
					0,
					image.get_width() - 1)
			var rim_y := clampi(
					roundi(float(y) + light_dir.y * rim_width),
					0,
					image.get_height() - 1)
			var outside_alpha := image.get_pixel(rim_x, rim_y).a
			var rim := clampf(source.a - outside_alpha, 0.0, 1.0)
			var rim_palette_target := _luma_preserving_palette(
					rim_color,
					minf(color.get_luminance() + 0.04, 0.56))
			color = color.lerp(
					rim_palette_target,
					rim * clampf(rim_strength, 0.0, 1.0))
			var idle_gain := 1.0 \
					+ (idle_envelope * 2.0 - 1.0) * idle_light_amount
			color.r *= idle_gain
			color.g *= idle_gain
			color.b *= idle_gain
			graded.set_pixel(x, y, color)
	return graded


func _luma_preserving_palette(palette: Color, target_luma: float) -> Color:
	var palette_luma := maxf(palette.get_luminance(), 0.001)
	var palette_target := Color(
			palette.r * target_luma / palette_luma,
			palette.g * target_luma / palette_luma,
			palette.b * target_luma / palette_luma,
			1.0).clamp()
	var corrected_luma := maxf(palette_target.get_luminance(), 0.001)
	return Color(
			clampf(palette_target.r * target_luma / corrected_luma, 0.0, 1.0),
			clampf(palette_target.g * target_luma / corrected_luma, 0.0, 1.0),
			clampf(palette_target.b * target_luma / corrected_luma, 0.0, 1.0),
			1.0)


func _animation_temporal_stats(
		sprite: AnimatedSprite2D,
		material: ShaderMaterial) -> Vector4:
	var frame_count := sprite.sprite_frames.get_frame_count(sprite.animation)
	var max_introduced_blue_fraction := 0.0
	var max_introduced_gold_fraction := 0.0
	var min_chroma_delta := INF
	var max_chroma_delta := -INF
	var min_luma := INF
	var max_luma := -INF
	for frame_index: int in range(frame_count):
		var frame_texture := sprite.sprite_frames.get_frame_texture(
				sprite.animation, frame_index)
		var source := frame_texture.get_image()
		var graded := _grade_image(source, material)
		var frame_stats := _introduced_palette_stats(source, graded)
		max_introduced_blue_fraction = maxf(
				max_introduced_blue_fraction, frame_stats.x)
		max_introduced_gold_fraction = maxf(
				max_introduced_gold_fraction, frame_stats.y)
		min_chroma_delta = minf(min_chroma_delta, frame_stats.z)
		max_chroma_delta = maxf(max_chroma_delta, frame_stats.z)
		var graded_stats := _visible_stats(graded)
		min_luma = minf(min_luma, graded_stats.x)
		max_luma = maxf(max_luma, graded_stats.x)
	return Vector4(
			max_introduced_blue_fraction,
			max_introduced_gold_fraction,
			max_chroma_delta - min_chroma_delta,
			max_luma - min_luma)


func _idle_cycle_stats(image: Image, material: ShaderMaterial) -> Vector2:
	var dark := _grade_image(image, material, 0.0)
	var bright := _grade_image(image, material, 1.0)
	return Vector2(
			_visible_stats(bright).x - _visible_stats(dark).x,
			_mean_warm_ratio(bright) - _mean_warm_ratio(dark))


func _mean_warm_ratio(image: Image) -> float:
	var ratio_sum := 0.0
	var visible_count := 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var sample := image.get_pixel(x, y)
			if sample.a <= 0.05:
				continue
			ratio_sum += (sample.r - sample.b) \
					/ maxf(sample.get_luminance(), 0.05)
			visible_count += 1
	return ratio_sum / float(maxi(visible_count, 1))


func _introduced_palette_stats(source: Image, graded: Image) -> Vector3:
	var visible_count := 0
	var introduced_blue_count := 0
	var introduced_gold_count := 0
	var chroma_delta_sum := 0.0
	for y: int in range(source.get_height()):
		for x: int in range(source.get_width()):
			var source_pixel := source.get_pixel(x, y)
			if source_pixel.a <= 0.05:
				continue
			var graded_pixel := graded.get_pixel(x, y)
			var source_blue := source_pixel.b \
					- maxf(source_pixel.r, source_pixel.g)
			var graded_blue := graded_pixel.b \
					- maxf(graded_pixel.r, graded_pixel.g)
			if graded_blue > 0.16 and graded_blue - source_blue > 0.10:
				introduced_blue_count += 1
			var source_gold := minf(
					source_pixel.r - source_pixel.g,
					source_pixel.g - source_pixel.b)
			var graded_gold := minf(
					graded_pixel.r - graded_pixel.g,
					graded_pixel.g - graded_pixel.b)
			if graded_gold > 0.14 and source_gold < 0.08:
				introduced_gold_count += 1
			chroma_delta_sum += (graded_pixel.r - graded_pixel.b) \
					- (source_pixel.r - source_pixel.b)
			visible_count += 1
	return Vector3(
			float(introduced_blue_count) / float(maxi(visible_count, 1)),
			float(introduced_gold_count) / float(maxi(visible_count, 1)),
			chroma_delta_sum / float(maxi(visible_count, 1)))


func _directional_warm_bias(
		source: Image,
		graded: Image,
		material: ShaderMaterial) -> float:
	var light_dir: Vector2 = material.get_shader_parameter("light_dir")
	light_dir = light_dir.normalized()
	var lit_delta_sum := 0.0
	var shade_delta_sum := 0.0
	var lit_count := 0
	var shade_count := 0
	for y: int in range(source.get_height()):
		for x: int in range(source.get_width()):
			var source_pixel := source.get_pixel(x, y)
			if source_pixel.a <= 0.05:
				continue
			var uv := Vector2(
					(float(x) + 0.5) / float(source.get_width()),
					(float(y) + 0.5) / float(source.get_height()))
			var directional_sample := (uv - Vector2(0.5, 0.5)).dot(light_dir)
			var graded_pixel := graded.get_pixel(x, y)
			var warm_delta := (graded_pixel.r - graded_pixel.b) \
					- (source_pixel.r - source_pixel.b)
			if directional_sample >= 0.16:
				lit_delta_sum += warm_delta
				lit_count += 1
			elif directional_sample <= -0.08:
				shade_delta_sum += warm_delta
				shade_count += 1
	var lit_average := lit_delta_sum / float(maxi(lit_count, 1))
	var shade_average := shade_delta_sum / float(maxi(shade_count, 1))
	return lit_average - shade_average


func _directional_shadow_cool_bias(
		source: Image,
		graded: Image,
		material: ShaderMaterial) -> float:
	var light_dir: Vector2 = material.get_shader_parameter("light_dir")
	light_dir = light_dir.normalized()
	var shade_delta_sum := 0.0
	var mid_delta_sum := 0.0
	var shade_count := 0
	var mid_count := 0
	for y: int in range(source.get_height()):
		for x: int in range(source.get_width()):
			var source_pixel := source.get_pixel(x, y)
			if source_pixel.a <= 0.05:
				continue
			var uv := Vector2(
					(float(x) + 0.5) / float(source.get_width()),
					(float(y) + 0.5) / float(source.get_height()))
			var directional_sample := (uv - Vector2(0.5, 0.5)).dot(light_dir)
			var graded_pixel := graded.get_pixel(x, y)
			var cool_delta := (graded_pixel.b - graded_pixel.r) \
					- (source_pixel.b - source_pixel.r)
			if directional_sample <= -0.16:
				shade_delta_sum += cool_delta
				shade_count += 1
			elif absf(directional_sample) <= 0.035:
				mid_delta_sum += cool_delta
				mid_count += 1
	var shade_average := shade_delta_sum / float(maxi(shade_count, 1))
	var mid_average := mid_delta_sum / float(maxi(mid_count, 1))
	return shade_average - mid_average


func _bright_facing_luma_lift(
		source: Image,
		graded: Image,
		material: ShaderMaterial) -> float:
	var light_dir: Vector2 = material.get_shader_parameter("light_dir")
	light_dir = light_dir.normalized()
	var lift_sum := 0.0
	var sample_count := 0
	for y: int in range(source.get_height()):
		for x: int in range(source.get_width()):
			var source_pixel := source.get_pixel(x, y)
			if source_pixel.a <= 0.05 or source_pixel.get_luminance() < 0.45:
				continue
			var uv := Vector2(
					(float(x) + 0.5) / float(source.get_width()),
					(float(y) + 0.5) / float(source.get_height()))
			if (uv - Vector2(0.5, 0.5)).dot(light_dir) < 0.16:
				continue
			lift_sum += graded.get_pixel(x, y).get_luminance() \
					- source_pixel.get_luminance()
			sample_count += 1
	return lift_sum / float(maxi(sample_count, 1))


func _visible_stats(image: Image) -> Vector4:
	var luma_sum := 0.0
	var saturation_sum := 0.0
	var visible_count := 0
	var dark_count := 0
	var bright_count := 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var sample := image.get_pixel(x, y)
			if sample.a <= 0.05:
				continue
			var luma := sample.get_luminance()
			luma_sum += luma
			saturation_sum += maxf(sample.r, maxf(sample.g, sample.b)) \
					- minf(sample.r, minf(sample.g, sample.b))
			visible_count += 1
			dark_count += 1 if luma < 0.20 else 0
			bright_count += 1 if luma > 0.78 else 0
	if visible_count == 0:
		return Vector4.ZERO
	return Vector4(
			luma_sum / float(visible_count),
			saturation_sum / float(visible_count),
			float(dark_count) / float(visible_count),
			float(bright_count) / float(visible_count))
