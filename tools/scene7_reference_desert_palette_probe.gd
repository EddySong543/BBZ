extends SceneTree

const REFERENCE_PATHS: Array[String] = [
	"res://ref/ref40.png",
	"res://ref/ref41.png",
	"res://ref/ref42.png",
]
const SCENE7_PATH := "res://src/ui/scenes/scene7.tscn"


func _initialize() -> void:
	call_deferred("_run_probe")


func _run_probe() -> void:
	var combined: Array[Color] = []
	var references_ready := true
	for reference_path: String in REFERENCE_PATHS:
		var absolute_path := ProjectSettings.globalize_path(reference_path)
		var image := Image.load_from_file(absolute_path)
		if image == null or image.is_empty():
			references_ready = false
			push_error("SCENE7_REFERENCE_DESERT: unable to load %s" % reference_path)
			continue
		var samples := _collect_desert_samples(image)
		if samples.size() < 256:
			references_ready = false
			push_error("SCENE7_REFERENCE_DESERT: insufficient samples for %s" % reference_path)
			continue
		combined.append_array(samples)
		_print_palette(reference_path, image.get_size(), samples)
	if combined.size() < 768:
		references_ready = false
	else:
		_print_palette("combined_ref40_ref41_ref42", Vector2i.ZERO, combined)
		combined.sort_custom(
				func(a: Color, b: Color) -> bool: return _luma(a) < _luma(b))
		var reference_shadow := _window_mean(combined, 0.16, 0.05)
		var reference_middle := _window_mean(combined, 0.50, 0.06)
		var reference_highlight := _window_mean(combined, 0.84, 0.05)
		var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
		root.add_child(stage)
		var material := (
				stage.get_node("FarBackground") as TextureRect).material as ShaderMaterial
		var scene_matches_reference := (
				_color_delta(material.get_shader_parameter("sand_shadow_color"),
						reference_shadow) <= 0.035
				and _color_delta(material.get_shader_parameter("sand_mid_color"),
						reference_middle) <= 0.035
				and _color_delta(material.get_shader_parameter("sand_highlight_color"),
						reference_highlight) <= 0.035
				and float(material.get_shader_parameter("sand_palette_strength")) >= 0.82
				and float(material.get_shader_parameter("sand_saturation")) >= 1.12
				and float(material.get_shader_parameter(
						"far_saturation_retention")) >= 0.70
				and float(material.get_shader_parameter("air_strength")) <= 0.18)
		references_ready = references_ready and scene_matches_reference
		print(
				"SCENE7_REFERENCE_DESERT_MATCH: ",
				"PASS" if scene_matches_reference else "FAIL",
				" scene_matches_reference=", scene_matches_reference)
		stage.queue_free()
	print(
			"SCENE7_REFERENCE_DESERT_PALETTE: ",
			"PASS" if references_ready else "FAIL",
			" references=", REFERENCE_PATHS.size(),
			" combined_samples=", combined.size())
	quit(0 if references_ready else 1)


func _collect_desert_samples(image: Image) -> Array[Color]:
	return _collect_desert_samples_region(image, 0.12, 0.68)


func _collect_desert_samples_region(
		image: Image, y_start_ratio: float, y_end_ratio: float) -> Array[Color]:
	var samples: Array[Color] = []
	var x_start := int(float(image.get_width()) * 0.05)
	var x_end := int(float(image.get_width()) * 0.95)
	var y_start := int(float(image.get_height()) * y_start_ratio)
	var y_end := int(float(image.get_height()) * y_end_ratio)
	for y: int in range(y_start, y_end, 4):
		for x: int in range(x_start, x_end, 4):
			var color := image.get_pixel(x, y)
			if color.a < 0.95:
				continue
			var hue_degrees := color.h * 360.0
			if hue_degrees < 18.0 or hue_degrees > 85.0:
				continue
			if color.s < 0.10 or color.s > 0.86:
				continue
			if color.v < 0.12 or color.v > 0.96:
				continue
			samples.append(color)
	return samples


func _print_palette(label: String, size: Vector2i, samples: Array[Color]) -> void:
	samples.sort_custom(func(a: Color, b: Color) -> bool: return _luma(a) < _luma(b))
	var shadow := _window_mean(samples, 0.16, 0.05)
	var middle := _window_mean(samples, 0.50, 0.06)
	var highlight := _window_mean(samples, 0.84, 0.05)
	var mean_saturation := 0.0
	var mean_hue := 0.0
	var saturations: Array[float] = []
	for color: Color in samples:
		mean_saturation += color.s
		mean_hue += color.h * 360.0
		saturations.append(color.s)
	mean_saturation /= float(samples.size())
	mean_hue /= float(samples.size())
	saturations.sort()
	print(
			"SCENE7_REFERENCE_DESERT: ", label,
			" size=", size,
			" samples=", samples.size(),
			" mean_hue=", snappedf(mean_hue, 0.1),
			" mean_saturation=", snappedf(mean_saturation, 0.001),
			" saturation_q50=", snappedf(
					saturations[int(float(saturations.size() - 1) * 0.50)], 0.001),
			" q70=", snappedf(
					saturations[int(float(saturations.size() - 1) * 0.70)], 0.001),
			" shadow=", _color_text(shadow),
			" middle=", _color_text(middle),
			" highlight=", _color_text(highlight))


func _window_mean(samples: Array[Color], center_ratio: float, radius_ratio: float) -> Color:
	var start := clampi(
			int(float(samples.size()) * (center_ratio - radius_ratio)),
			0,
			samples.size() - 1)
	var end := clampi(
			int(float(samples.size()) * (center_ratio + radius_ratio)),
			start + 1,
			samples.size())
	var total := Color(0.0, 0.0, 0.0, 0.0)
	for index: int in range(start, end):
		total += samples[index]
	return total / float(end - start)


func _color_text(color: Color) -> String:
	return "rgb(%.3f,%.3f,%.3f) hsv(%.1f,%.3f,%.3f) luma=%.3f" % [
		color.r,
		color.g,
		color.b,
		color.h * 360.0,
		color.s,
		color.v,
		_luma(color),
	]


func _luma(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722


func _color_delta(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
