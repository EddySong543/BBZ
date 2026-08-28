extends SceneTree

const BATTLE7_PATH := "res://src/ui/battle_screen7.tscn"
const CHARACTER_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_character_light.gdshader"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	(root.get_node("BattleSetup") as Node).call("reset")
	var screen := (load(BATTLE7_PATH) as PackedScene).instantiate()
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
		var source_stats := _visible_stats(frame_texture.get_image())
		var rendered_stats := _graded_stats(frame_texture.get_image(), material)
		var legacy_stats := _legacy_double_sample_stats(
				frame_texture.get_image(), material)
		var frame_passed := (
			material != null
			and material.shader.resource_path == CHARACTER_SHADER_PATH
			and material.resource_local_to_scene
			and float(material.get_shader_parameter("sun_key_amount")) == 0.12
			and float(material.get_shader_parameter("oasis_bounce_amount")) == 0.10
			and rendered_stats.x >= source_stats.x - 0.018
			and rendered_stats.x <= source_stats.x + 0.045
			and rendered_stats.x >= legacy_stats.x + 0.08
			and absf(rendered_stats.y - source_stats.y) <= 0.07
			and rendered_stats.z <= source_stats.z + 0.035
			and rendered_stats.w <= source_stats.w + 0.035)
		passed = passed and frame_passed
		print(
			"SCENE7_CHARACTER_GRADE_LAYER: ", "PASS" if frame_passed else "FAIL",
			" display=", display_name,
			" source_luma=", snappedf(source_stats.x, 0.001),
			" rendered_luma=", snappedf(rendered_stats.x, 0.001),
			" legacy_double_luma=", snappedf(legacy_stats.x, 0.001),
			" source_saturation=", snappedf(source_stats.y, 0.001),
			" rendered_saturation=", snappedf(rendered_stats.y, 0.001),
			" source_dark_fraction=", snappedf(source_stats.z, 0.001),
			" rendered_dark_fraction=", snappedf(rendered_stats.z, 0.001),
			" source_bright_fraction=", snappedf(source_stats.w, 0.001),
			" rendered_bright_fraction=", snappedf(rendered_stats.w, 0.001))
	passed = passed and materials.size() == 2 and materials[0] != materials[1]
	print("SCENE7_CHARACTER_GRADE_PROBE: ", "PASS" if passed else "FAIL")
	screen.free()
	quit(0 if passed else 1)


func _legacy_double_sample_stats(image: Image, material: ShaderMaterial) -> Vector4:
	var graded := image.duplicate()
	var lit_image := _graded_image(image, material)
	for y: int in range(graded.get_height()):
		for x: int in range(graded.get_width()):
			var source: Color = graded.get_pixel(x, y)
			var lit: Color = lit_image.get_pixel(x, y)
			graded.set_pixel(x, y, Color(
					lit.r * source.r,
					lit.g * source.g,
					lit.b * source.b,
					lit.a * source.a))
	return _visible_stats(graded)


func _graded_stats(image: Image, material: ShaderMaterial) -> Vector4:
	return _visible_stats(_graded_image(image, material))


func _graded_image(image: Image, material: ShaderMaterial) -> Image:
	var graded := image.duplicate()
	var light_dir: Vector2 = material.get_shader_parameter("light_dir")
	light_dir = light_dir.normalized()
	var source_saturation := float(material.get_shader_parameter("source_saturation"))
	var source_contrast := float(material.get_shader_parameter("source_contrast"))
	var scene_exposure := float(material.get_shader_parameter("scene_exposure"))
	var highlight_compression := float(material.get_shader_parameter(
			"highlight_compression"))
	var backlight := float(material.get_shader_parameter("backlight"))
	var shadow_tint: Color = material.get_shader_parameter("shadow_tint")
	var skin_warmth: Color = material.get_shader_parameter("skin_warmth")
	var warmth_amount := float(material.get_shader_parameter("warmth_amount"))
	var fill_color: Color = material.get_shader_parameter("fill_color")
	var fill_amount := float(material.get_shader_parameter("fill_amount"))
	var sun_key_color: Color = material.get_shader_parameter("sun_key_color")
	var sun_key_amount := float(material.get_shader_parameter("sun_key_amount"))
	var oasis_bounce_color: Color = material.get_shader_parameter(
			"oasis_bounce_color")
	var oasis_bounce_amount := float(material.get_shader_parameter(
			"oasis_bounce_amount"))
	var oasis_bounce_start := float(material.get_shader_parameter(
			"oasis_bounce_start"))
	for y: int in range(graded.get_height()):
		for x: int in range(graded.get_width()):
			var source: Color = graded.get_pixel(x, y)
			if source.a <= 0.05:
				continue
			var uv := Vector2(
					(float(x) + 0.5) / float(graded.get_width()),
					(float(y) + 0.5) / float(graded.get_height()))
			var source_luma := source.get_luminance()
			var color := Color(source_luma, source_luma, source_luma, source.a) \
					.lerp(source, source_saturation)
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
			var lit := (uv - Vector2(0.5, 0.5)).dot(light_dir)
			var light_side := smoothstep(-0.34, 0.34, lit)
			var shadow_band := 1.0 - smoothstep(-0.32, 0.04, lit)
			var sun_band := smoothstep(0.08, 0.36, lit)
			var shadow_luma := color.get_luminance() * (1.0 - backlight * 0.22)
			var shadow_target := _luma_preserving_palette(
					shadow_tint, shadow_luma, color.a)
			color = color.lerp(shadow_target, backlight * shadow_band)
			color = color.lerp(Color(
					color.r * skin_warmth.r,
					color.g * skin_warmth.g,
					color.b * skin_warmth.b,
					color.a), warmth_amount)
			var luma: float = color.get_luminance()
			var fill_weight: float = (0.68 + 0.20 * light_side) \
					* (1.0 - luma * 0.7)
			color.r += fill_color.r * fill_amount * fill_weight
			color.g += fill_color.g * fill_amount * fill_weight
			color.b += fill_color.b * fill_amount * fill_weight

			var upper_key := 1.0 - smoothstep(0.18, 0.86, uv.y)
			luma = color.get_luminance()
			var sun_target := _luma_preserving_palette(
					sun_key_color,
					minf(luma + 0.018 * (1.0 - luma * 0.7), 0.76),
					color.a)
			color = color.lerp(
					sun_target,
					sun_key_amount * sun_band * (0.62 + upper_key * 0.38))

			var oasis_bounce := smoothstep(oasis_bounce_start, 0.94, uv.y)
			oasis_bounce = floorf(oasis_bounce * 4.0 + 0.5) / 4.0
			luma = color.get_luminance()
			var bounce_target := _luma_preserving_palette(
					oasis_bounce_color,
					minf(luma + 0.012 * (1.0 - luma), 0.68),
					color.a)
			color = color.lerp(
					bounce_target,
					oasis_bounce_amount * oasis_bounce * (1.0 - sun_band * 0.30))
			graded.set_pixel(x, y, color)
	return graded


func _luma_preserving_palette(
		palette_color: Color,
		target_luma: float,
		alpha: float) -> Color:
	var palette_luma := maxf(palette_color.get_luminance(), 0.001)
	var target := Color(
			clampf(palette_color.r * target_luma / palette_luma, 0.0, 1.0),
			clampf(palette_color.g * target_luma / palette_luma, 0.0, 1.0),
			clampf(palette_color.b * target_luma / palette_luma, 0.0, 1.0),
			alpha)
	var correction := target_luma / maxf(target.get_luminance(), 0.001)
	return Color(
			clampf(target.r * correction, 0.0, 1.0),
			clampf(target.g * correction, 0.0, 1.0),
			clampf(target.b * correction, 0.0, 1.0),
			alpha)


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
