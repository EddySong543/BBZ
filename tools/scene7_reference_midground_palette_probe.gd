extends SceneTree

const SCENE7 := preload("res://src/ui/scenes/scene7.tscn")
const REFERENCES: Array[String] = [
	"res://ref/ref40.png",
	"res://ref/ref41.png",
	"res://ref/ref42.png",
]
const MIDGROUNDS: Array[String] = [
	"MidgroundLeft",
	"MidgroundCenter",
	"MidgroundRight",
]
const PRESETS := preload("res://tools/scene7_midground_palette_presets.gd")
const PRESET_KEYS := {
	"MidgroundLeft": "left",
	"MidgroundCenter": "center",
	"MidgroundRight": "right",
}


func _initialize() -> void:
	var reference_body: Array[Color] = []
	var reference_glow: Array[Color] = []
	for path: String in REFERENCES:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		_collect_reference_colors(image, reference_body, reference_glow)
	var reference_body_luma := _mean_luma(reference_body)
	var reference_glow_luma := _mean_luma(reference_glow)

	var stage := SCENE7.instantiate() as BattleStage
	root.add_child(stage)
	var passed := (
			reference_body.size() >= 5000
			and reference_glow.size() >= 2000
			and reference_body_luma >= 0.34
			and reference_body_luma <= 0.39
			and reference_glow_luma >= 0.67
			and reference_glow_luma <= 0.74)
	for node_name: String in MIDGROUNDS:
		var material := (
				stage.get_node(node_name) as TextureRect).material as ShaderMaterial
		var shadow: Color = material.get_shader_parameter("shadow_palette")
		var sunlit: Color = material.get_shader_parameter("sunlit_palette")
		var glow: Color = material.get_shader_parameter("glow_color")
		var base_brightness := float(material.get_shader_parameter("base_brightness"))
		var palette_mid_luma := (_luma(shadow) + _luma(sunlit)) * 0.5 \
				* base_brightness
		var exact_rollback := true
		var expected: Dictionary = PRESETS.PRE_BRIGHTEN_ROLLBACK[
				PRESET_KEYS[node_name]]
		for parameter_name: String in expected:
			exact_rollback = exact_rollback and _variant_matches(
					material.get_shader_parameter(parameter_name),
					expected[parameter_name])
		var layer_passed := (
				material.resource_local_to_scene
				and exact_rollback
				and palette_mid_luma < reference_body_luma - 0.08
				and absf(_luma(glow) - reference_glow_luma) <= 0.075
				and base_brightness >= 0.88
				and base_brightness <= 0.93
				and float(material.get_shader_parameter("palette_strength")) >= 0.35
				and float(material.get_shader_parameter("palette_strength")) <= 0.39
				and float(material.get_shader_parameter(
						"source_cyan_midtone_lift")) >= 0.07
				and float(material.get_shader_parameter(
						"source_cyan_midtone_lift")) <= 0.085
				and float(material.get_shader_parameter(
						"source_cyan_compression")) >= 0.17
				and float(material.get_shader_parameter(
						"source_cyan_compression")) <= 0.19
				and float(material.get_shader_parameter("emission_strength")) <= 0.08
				and float(material.get_shader_parameter("core_value_ceiling")) <= 0.80)
		passed = passed and layer_passed
		print(
			"SCENE7_REFERENCE_MIDGROUND_LAYER: ",
			"PASS" if layer_passed else "FAIL",
			" node=", node_name,
			" palette_mid_luma=", snappedf(palette_mid_luma, 0.001),
			" glow_luma=", snappedf(_luma(glow), 0.001))
	print(
		"SCENE7_REFERENCE_MIDGROUND_PALETTE: ",
		"PASS" if passed else "FAIL",
		" active_preset=PRE_BRIGHTEN_ROLLBACK",
		" clean_backup_layers=", PRESETS.CLEAN_BRIGHT_BACKUP.size(),
		" body_samples=", reference_body.size(),
		" body_luma=", snappedf(reference_body_luma, 0.001),
		" glow_samples=", reference_glow.size(),
		" glow_luma=", snappedf(reference_glow_luma, 0.001))
	stage.queue_free()
	quit(0 if passed else 1)


func _collect_reference_colors(
		image: Image,
		body: Array[Color],
		glow: Array[Color]) -> void:
	var x_start := int(float(image.get_width()) * 0.04)
	var x_end := int(float(image.get_width()) * 0.96)
	var y_start := int(float(image.get_height()) * 0.24)
	var y_end := int(float(image.get_height()) * 0.70)
	for y: int in range(y_start, y_end, 3):
		for x: int in range(x_start, x_end, 3):
			var color := image.get_pixel(x, y)
			var hue := color.h * 360.0
			if hue < 92.0 or hue > 215.0 or color.s < 0.16:
				continue
			if color.v >= 0.24 and color.v < 0.70:
				body.append(color)
			elif color.v >= 0.70:
				glow.append(color)


func _mean_luma(colors: Array[Color]) -> float:
	if colors.is_empty():
		return 0.0
	var total := 0.0
	for color: Color in colors:
		total += _luma(color)
	return total / float(colors.size())


func _luma(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722


func _variant_matches(actual: Variant, expected: Variant) -> bool:
	if actual is Color and expected is Color:
		var actual_color: Color = actual
		var expected_color: Color = expected
		return actual_color.is_equal_approx(expected_color)
	if actual is float or actual is int:
		return is_equal_approx(float(actual), float(expected))
	return actual == expected
