extends Node

const CHARACTER_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_character_light.gdshader"
const CHARACTER_DISPLAY_PATH := \
		"res://src/ui/components/character_display.tscn"
const CHARACTER_FRAME_PATHS: Array[String] = [
	"res://assets/sprites/heroes/h01/h01_idle.tres",
	"res://assets/sprites/heroes/h02/h02_idle.tres",
]


func _ready() -> void:
	get_window().size = Vector2i(640, 640)
	get_window().position = Vector2i.ZERO
	RenderingServer.set_default_clear_color(Color.BLACK)
	var passed := true
	for frame_path: String in CHARACTER_FRAME_PATHS:
		var frames := load(frame_path) as SpriteFrames
		var source_stats: Vector4 = await _render_stats(
				frames, _passthrough_material())
		var rendered_stats: Vector4 = await _render_stats(
				frames, _character_material())
		var frame_passed := (
			absf(rendered_stats.x - source_stats.x) <= 0.025
			and absf(rendered_stats.y - source_stats.y) <= 0.02
			and absf(rendered_stats.z - source_stats.z) <= 0.05
			and rendered_stats.w <= source_stats.w + 0.03)
		passed = passed and frame_passed
		print(
			"SCENE7_CHARACTER_GRADE_LAYER: ", "PASS" if frame_passed else "FAIL",
			" frame=", frame_path.get_file(),
			" source_luma=", snappedf(source_stats.x, 0.001),
			" rendered_luma=", snappedf(rendered_stats.x, 0.001),
			" source_saturation=", snappedf(source_stats.y, 0.001),
			" rendered_saturation=", snappedf(rendered_stats.y, 0.001),
			" source_dark_fraction=", snappedf(source_stats.z, 0.001),
			" rendered_dark_fraction=", snappedf(rendered_stats.z, 0.001),
			" source_bright_fraction=", snappedf(source_stats.w, 0.001),
			" rendered_bright_fraction=", snappedf(rendered_stats.w, 0.001))
	print("SCENE7_CHARACTER_GRADE_PROBE: ", "PASS" if passed else "FAIL")
	get_tree().quit(0 if passed else 1)


func _render_stats(frames: SpriteFrames, material: ShaderMaterial) -> Vector4:
	var display := (load(CHARACTER_DISPLAY_PATH) as PackedScene).instantiate() \
			as CharacterDisplay
	display.rim_strength = 0.0
	display.backlight = 0.0
	display.shadow_tint = Color(0.86, 0.9, 0.88, 1.0)
	display.warmth_amount = 0.0
	display.fill_amount = 0.0
	var sprite := display.get_node("SubViewport/AnimatedSprite2D") as AnimatedSprite2D
	sprite.sprite_frames = frames
	sprite.animation = &"idle"
	sprite.frame = 0
	sprite.material = material
	add_child(display)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var stats := _visible_stats(display.get_render_texture().get_image())
	display.queue_free()
	await get_tree().process_frame
	return stats


func _passthrough_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = (
		"shader_type canvas_item;\n"
		+ "render_mode unshaded;\n"
		+ "void fragment() { COLOR = texture(TEXTURE, UV); }\n")
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _character_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(CHARACTER_SHADER_PATH) as Shader
	material.set_shader_parameter("source_saturation", 1.0)
	material.set_shader_parameter("source_contrast", 1.0)
	material.set_shader_parameter("ambient_tint_amount", 0.0)
	material.set_shader_parameter("highlight_shoulder_strength", 0.0)
	material.set_shader_parameter("backlight", 0.0)
	material.set_shader_parameter("shadow_tint", Color(0.86, 0.9, 0.88, 1.0))
	material.set_shader_parameter("warmth_amount", 0.0)
	material.set_shader_parameter("rim_strength", 0.0)
	material.set_shader_parameter("fill_amount", 0.0)
	material.set_shader_parameter("daylight_key_amount", 0.0)
	material.set_shader_parameter("water_bounce_amount", 0.0)
	return material


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
