extends SceneTree

const GOLD_SOURCE_PATH := (
	"res://assets/ui/boot/boot_pressure_gold_combined.png")
const GOLD_PATH_OUTPUT := (
	"res://assets/ui/boot/boot_pressure_gold_intro_path.png")
const BLUE_PATH_OUTPUT := (
	"res://assets/ui/boot/boot_pressure_blue_intro_path.png")
const RING_CENTER := Vector2(843.0, 295.0)
# The star/character-head contact point maps to roughly 33 degrees in the
# authored texture. Screen-space Y grows downward, so increasing angle is the
# requested clockwise direction.
const GOLD_START_ANGLE := 0.575958653


func _init() -> void:
	var source := Image.load_from_file(
		ProjectSettings.globalize_path(GOLD_SOURCE_PATH))
	if source == null or source.is_empty():
		push_error("Boot gold source could not be loaded.")
		quit(1)
		return
	source.convert(Image.FORMAT_RGBA8)

	var gold_path := Image.create(
		source.get_width(),
		source.get_height(),
		false,
		Image.FORMAT_RGBA8)
	var blue_path := Image.create(
		source.get_width(),
		source.get_height(),
		false,
		Image.FORMAT_RGBA8)
	for y: int in source.get_height():
		for x: int in source.get_width():
			var pixel_position := Vector2(float(x), float(y))
			var delta := pixel_position - RING_CENTER
			var clockwise_angle := atan2(delta.y, delta.x)
			var clockwise_phase := (
				fposmod(
					clockwise_angle - GOLD_START_ANGLE,
					TAU)
				/ TAU)
			var radial_offset := (
				clampf(
					(delta.length() - 90.0) / 430.0,
					0.0,
					1.0)
				* 0.055)
			var gold_cluster := (
				_value_noise(x, y, 36) - 0.5) * 0.10
			var gold_detail := (
				_value_noise(x, y, 12) - 0.5) * 0.03
			var gold_progress := clampf(
				clockwise_phase
					+ radial_offset
					+ gold_cluster
					+ gold_detail,
				0.0,
				1.0)
			gold_path.set_pixel(
				x,
				y,
				Color(
					gold_progress,
					gold_progress,
					gold_progress,
					1.0))

			var normalized := Vector2(
				float(x) / maxf(source.get_width() - 1.0, 1.0),
				float(y) / maxf(source.get_height() - 1.0, 1.0))
			var diagonal_progress := (
				1.0 - normalized.x + normalized.y) * 0.5
			var blue_cluster := (
				_value_noise(x, y, 48) - 0.5) * 0.06
			var blue_detail := (
				_value_noise(x, y, 16) - 0.5) * 0.015
			var blue_progress := clampf(
				diagonal_progress + blue_cluster + blue_detail,
				0.0,
				1.0)
			blue_path.set_pixel(
				x,
				y,
				Color(
					blue_progress,
					blue_progress,
					blue_progress,
					1.0))

	if not _save_image(gold_path, GOLD_PATH_OUTPUT):
		quit(1)
		return
	if not _save_image(blue_path, BLUE_PATH_OUTPUT):
		quit(1)
		return
	print(
		"BOOT_INTRO_PATHS_OK: size=%dx%d"
		% [source.get_width(), source.get_height()])
	quit()


func _hash_cell(x: int, y: int) -> float:
	var hashed := (
		(x * 73856093)
		^ (y * 19349663))
	hashed &= 0x7fffffff
	return float(hashed % 4096) / 4095.0


func _value_noise(x: int, y: int, cell_size: int) -> float:
	var safe_cell_size := maxi(cell_size, 1)
	var grid_x := float(x) / float(safe_cell_size)
	var grid_y := float(y) / float(safe_cell_size)
	var cell_x := floori(grid_x)
	var cell_y := floori(grid_y)
	var blend_x := smoothstep(
		0.0,
		1.0,
		grid_x - floorf(grid_x))
	var blend_y := smoothstep(
		0.0,
		1.0,
		grid_y - floorf(grid_y))
	var top := lerpf(
		_hash_cell(cell_x, cell_y),
		_hash_cell(cell_x + 1, cell_y),
		blend_x)
	var bottom := lerpf(
		_hash_cell(cell_x, cell_y + 1),
		_hash_cell(cell_x + 1, cell_y + 1),
		blend_x)
	return lerpf(top, bottom, blend_y)


func _save_image(image: Image, resource_path: String) -> bool:
	var output_path := ProjectSettings.globalize_path(resource_path)
	var error := image.save_png(output_path)
	if error != OK:
		push_error(
			"Boot intro path could not be saved: %s"
			% resource_path)
		return false
	return true
