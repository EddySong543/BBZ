extends SceneTree

const SOURCE_PATH := (
	"res://assets/ui/boot/boot_pressure_background_v2.png")
const RING_CENTER := Vector2(843.0, 295.0)
const GOLD_FLOW_DIRECTION := Vector2(0.52, -1.0)

const OUTPUT_PATHS: Dictionary[String, String] = {
	"blue_base":
		"res://assets/ui/boot/boot_pressure_blue_base.png",
	"blue_mid":
		"res://assets/ui/boot/boot_pressure_blue_mid.png",
	"blue_light":
		"res://assets/ui/boot/boot_pressure_blue_light.png",
	"gold_combined":
		"res://assets/ui/boot/boot_pressure_gold_combined.png",
	"gold_flow":
		"res://assets/ui/boot/boot_pressure_gold_flow.png",
}


func _init() -> void:
	var source := Image.load_from_file(
			ProjectSettings.globalize_path(SOURCE_PATH))
	if source == null or source.is_empty():
		push_error("Boot pressure source image could not be loaded.")
		quit(1)
		return
	source.convert(Image.FORMAT_RGBA8)

	var layers: Dictionary[String, Image] = {}
	for layer_name: String in OUTPUT_PATHS:
		layers[layer_name] = Image.create_empty(
				source.get_width(),
				source.get_height(),
				false,
				Image.FORMAT_RGBA8)
		if layer_name == "gold_flow":
			layers[layer_name].fill(Color(0.5, 0.5, 0.0, 0.0))

	var counts: Dictionary[String, int] = {}
	for layer_name: String in OUTPUT_PATHS:
		counts[layer_name] = 0

	for y: int in source.get_height():
		for x: int in source.get_width():
			var color := source.get_pixel(x, y)
			if color.a <= 0.001:
				continue

			var luminance := (
					color.r * 0.299
					+ color.g * 0.587
					+ color.b * 0.114)
			if _is_blue(color):
				_set_layer_pixel(
					layers,
					counts,
					&"blue_base",
					x,
					y,
					color)
				if luminance >= 0.25:
					var mid_color := color
					mid_color.a *= 0.56
					_set_layer_pixel(
						layers,
						counts,
						&"blue_mid",
						x,
						y,
						mid_color)
				if luminance >= 0.48:
					var light_color := color.lightened(0.08)
					light_color.a *= 0.68
					_set_layer_pixel(
						layers,
						counts,
						&"blue_light",
						x,
						y,
						light_color)

			if _is_gold(color):
				var radius := Vector2(float(x), float(y)).distance_to(
						RING_CENTER)
				if radius <= 430.0:
					_set_layer_pixel(
						layers,
						counts,
						&"gold_combined",
						x,
						y,
						color)

	_paint_gold_flow_map(
			layers["gold_flow"],
			source.get_width(),
			source.get_height())

	for layer_name: String in OUTPUT_PATHS:
		var output_path: String = OUTPUT_PATHS[layer_name]
		var error := layers[layer_name].save_png(
				ProjectSettings.globalize_path(output_path))
		if error != OK:
			push_error(
				"Could not save %s: %s"
				% [output_path, error_string(error)])
			quit(1)
			return

	print(
		"BOOT_PRESSURE_LAYERS_OK: size=%dx%d counts=%s"
		% [
			source.get_width(),
			source.get_height(),
			str(counts),
		])
	quit()


func _is_blue(color: Color) -> bool:
	return (
		color.b - color.r > 0.035
		and color.b > 0.18
		and color.h > 0.50
		and color.h < 0.70)


func _is_gold(color: Color) -> bool:
	return (
		color.s > 0.34
		and color.h > 0.045
		and color.h < 0.18
		and color.r > 0.34
		and color.g - color.b > 0.18
		and color.r - color.b > 0.30)


func _paint_gold_flow_map(
		flow_image: Image,
		width: int,
		height: int,
) -> void:
	for y: int in height:
		for x: int in width:
			var position := Vector2(float(x), float(y))
			var delta := position - RING_CENTER
			var radius := delta.length()
			var direction := Vector2.ZERO
			var flow_region := 0.0
			var phase := 0.0

			if radius <= 226.0:
				direction = GOLD_FLOW_DIRECTION.normalized()
				flow_region = 0.35
				phase = fposmod(
						delta.dot(direction) / 452.0 + 1.0,
						1.0)
			elif (
					radius <= 470.0
					and delta.y < -44.0
					and delta.x < 96.0
			):
				direction = GOLD_FLOW_DIRECTION.normalized()
				flow_region = 1.0
				phase = clampf(
						(delta.dot(direction) + 44.0) / 426.0,
						0.0,
						1.0)
			else:
				continue

			var encoded_direction := direction * 0.5 + Vector2(0.5, 0.5)
			flow_image.set_pixel(
					x,
					y,
					Color(
						encoded_direction.x,
						encoded_direction.y,
						flow_region,
						phase))


func _set_layer_pixel(
		layers: Dictionary[String, Image],
		counts: Dictionary[String, int],
		layer_name: StringName,
		x: int,
		y: int,
		color: Color,
) -> void:
	var key := String(layer_name)
	layers[key].set_pixel(x, y, color)
	counts[key] += 1
