extends SceneTree

## Image-free acceptance probe for Scene8's repaired and animated ref48 aurora.
## It protects the accepted static pixels, rejects old occlusion regressions,
## and proves that all eight horizontal regions participate in obvious motion.

const SCENE8: PackedScene = preload("res://src/ui/scenes/scene8.tscn")
const REF48_PATH := "res://ref/ref48.png"
const AURORA_PATH := "res://assets/scenes/scene8/scene8_ref48_aurora.png"
const MOTION_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene8_ref48_aurora_motion.gdshader"
const RETIRED_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene8_pixel_aurora.gdshader"
const EXPECTED_SHA256 := \
		"42648aea4431a8d2acd5ee1f8f75fc6633e9ae6c618fdc9ee2d54f75ed488e21"
const LOGICAL_SIZE := Vector2i(256, 144)
const SOURCE_SIZE := Vector2i(1024, 576)
const SOURCE_SCALE := 4
const AURORA_MAX_Y := 70
const PALETTE: Array[String] = [
	"4b429f", "8458c3", "777bc2", "2f60a6",
	"2a7ccf", "3193c8", "35baef", "39d5ea",
	"226a71", "338c88", "37a28f", "44b3bb", "53bca7", "29d8be",
	"4ac88e", "5ade8b", "40f1b9", "6df29e", "3cf4dc",
]
const FLUORESCENT_LOWER_COLORS: Array[String] = [
	"4ac88e", "5ade8b", "40f1b9", "6df29e", "3cf4dc", "29d8be",
	"39d5ea", "35baef",
]
const DIRTY_DARK_GREEN_COLORS: Array[String] = [
	"226a71", "338c88", "37a28f", "44b3bb", "53bca7",
]
const LEFT_MARKED_RECTS: Array[Rect2i] = [
	Rect2i(73, 41, 15, 17), Rect2i(88, 64, 7, 6),
]
const TREE_MARKED_RECTS: Array[Rect2i] = [
	Rect2i(146, 45, 9, 14), Rect2i(168, 44, 15, 8), Rect2i(191, 36, 8, 7),
]
const SCENE8_3_CUTOUT_RECTS: Array[Rect2i] = [
	Rect2i(72, 39, 7, 18), Rect2i(82, 49, 12, 21),
	Rect2i(78, 61, 8, 9), Rect2i(157, 58, 6, 6),
	Rect2i(178, 39, 10, 18), Rect2i(186, 43, 9, 15),
]
const RIGHT_TAIL_RECOLOR_RECT := Rect2i(214, 26, 42, 7)
const GREEN_TAIL_COLORS: Array[String] = [
	"4ac88e", "5ade8b", "40f1b9", "6df29e", "3cf4dc", "29d8be",
]
const SCENE8_4_RIGHT_CURVE_POINTS: Array[Vector2i] = [
	Vector2i(169, 63), Vector2i(180, 52), Vector2i(190, 45),
	Vector2i(197, 43), Vector2i(205, 40), Vector2i(213, 38),
	Vector2i(218, 31), Vector2i(223, 29), Vector2i(238, 29),
	Vector2i(243, 32), Vector2i(255, 30),
]
const LEFT_CLOSURE_ARC_POINTS: Array[Vector2i] = [
	Vector2i(82, 65), Vector2i(83, 67), Vector2i(85, 67), Vector2i(89, 69),
	Vector2i(93, 70), Vector2i(96, 68), Vector2i(100, 63),
]


var _stage: Node
var _aurora: TextureRect
var _motion_material: ShaderMaterial
var _reflection_material: ShaderMaterial
var _image: Image
var _reference: Image


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_stage = SCENE8.instantiate()
	root.add_child(_stage)
	await process_frame
	var setup := _initialize_sources()
	if not bool(setup["passed"]):
		print("SCENE8_AURORA_PROBE: FAIL setup=", setup)
		_stage.queue_free()
		quit(1)
		return
	var preservation := _probe_preserved_repair()
	var marked_cleanup := _probe_marked_cleanup()
	var distribution := _probe_pixel_distribution()
	var rendering := _probe_full_curtain_motion()
	var reflection := _probe_continuous_reflection()
	var passed := bool(preservation["passed"]) \
			and bool(marked_cleanup["passed"]) \
			and bool(distribution["passed"]) \
			and bool(rendering["passed"]) \
			and bool(reflection["passed"])
	print(
			"SCENE8_AURORA_PROBE: ", "PASS" if passed else "FAIL",
			" preservation=", preservation,
			" marked_cleanup=", marked_cleanup,
			" distribution=", distribution,
			" rendering=", rendering,
			" reflection=", reflection)
	_stage.queue_free()
	quit(0 if passed else 1)


func _initialize_sources() -> Dictionary:
	_aurora = _stage.get_node_or_null("PixelAurora") as TextureRect
	var reflection := _stage.get_node_or_null("AuroraReflection") as ColorRect
	if _aurora == null or reflection == null:
		return {"passed": false, "error": "missing_scene8_nodes"}
	_reflection_material = reflection.material as ShaderMaterial
	_motion_material = _aurora.material as ShaderMaterial
	if _aurora.texture == null or _motion_material == null \
			or _reflection_material == null:
		return {"passed": false, "error": "missing_resources"}
	_image = _aurora.texture.get_image()
	_reference = Image.load_from_file(REF48_PATH)
	return {
		"passed": _image != null and _reference != null
				and _image.get_size() == LOGICAL_SIZE
				and _reference.get_size() == SOURCE_SIZE,
		"aurora_size": _image.get_size() if _image != null else Vector2i.ZERO,
		"reference_size": (
				_reference.get_size() if _reference != null else Vector2i.ZERO),
	}


func _probe_preserved_repair() -> Dictionary:
	var top_by_column := PackedInt32Array()
	var bottom_by_column := PackedInt32Array()
	top_by_column.resize(LOGICAL_SIZE.x)
	top_by_column.fill(-1)
	bottom_by_column.resize(LOGICAL_SIZE.x)
	bottom_by_column.fill(-1)
	var opaque_count := 0
	var exact_source_pixels := 0
	var min_cell := Vector2i(LOGICAL_SIZE.x, LOGICAL_SIZE.y)
	var max_cell := Vector2i(-1, -1)
	for y: int in LOGICAL_SIZE.y:
		for x: int in LOGICAL_SIZE.x:
			var color := _image.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			opaque_count += 1
			if top_by_column[x] < 0:
				top_by_column[x] = y
			bottom_by_column[x] = y
			min_cell.x = mini(min_cell.x, x)
			min_cell.y = mini(min_cell.y, y)
			max_cell.x = maxi(max_cell.x, x)
			max_cell.y = maxi(max_cell.y, y)
			var ref_color := _reference.get_pixel(x * SOURCE_SCALE, y * SOURCE_SCALE)
			exact_source_pixels += int(
					color.r8 == ref_color.r8
					and color.g8 == ref_color.g8
					and color.b8 == ref_color.b8)
	var occupied_columns := 0
	var internal_transparent_pixels := 0
	var right_bottom_max_delta := 0
	var direction_changes := 0
	var previous_direction := 0
	for x: int in LOGICAL_SIZE.x:
		if top_by_column[x] < 0:
			continue
		occupied_columns += 1
		for y: int in range(top_by_column[x], bottom_by_column[x] + 1):
			internal_transparent_pixels += int(_image.get_pixel(x, y).a <= 0.0)
		if x == 0:
			continue
		var delta := bottom_by_column[x] - bottom_by_column[x - 1]
		if x >= 193:
			right_bottom_max_delta = maxi(right_bottom_max_delta, absi(delta))
		var direction := signi(delta)
		if direction != 0:
			if previous_direction != 0 and direction != previous_direction:
				direction_changes += 1
			previous_direction = direction
	var repaired_pixels := opaque_count - exact_source_pixels
	var bounds := Rect2i(min_cell, max_cell - min_cell + Vector2i.ONE)
	var hash := FileAccess.get_sha256(AURORA_PATH)
	return {
		"passed": opaque_count == 7416 and exact_source_pixels == 6355
				and repaired_pixels == 1061
				and occupied_columns == LOGICAL_SIZE.x
				and internal_transparent_pixels == 0
				and right_bottom_max_delta <= 2
				and direction_changes >= 17
				and bounds == Rect2i(0, 0, 256, 71)
				and hash == EXPECTED_SHA256,
		"opaque_count": opaque_count,
		"occupied_columns": occupied_columns,
		"exact_source_pixels": exact_source_pixels,
		"preserved_ratio": float(exact_source_pixels) / float(opaque_count),
		"repaired_pixels": repaired_pixels,
		"internal_transparent_pixels": internal_transparent_pixels,
		"right_bottom_max_delta": right_bottom_max_delta,
		"lower_edge_direction_changes": direction_changes,
		"bounds": bounds,
		"sha256": hash,
	}


func _probe_marked_cleanup() -> Dictionary:
	var fluorescent: Dictionary[int, bool] = {}
	for hex_color: String in FLUORESCENT_LOWER_COLORS:
		fluorescent[Color(hex_color).to_rgba32()] = true
	var dirty_dark_green: Dictionary[int, bool] = {}
	for hex_color: String in DIRTY_DARK_GREEN_COLORS:
		dirty_dark_green[Color(hex_color).to_rgba32()] = true
	var max_dirty_horizontal_run := 0
	var max_dirty_vertical_run := 0
	for rect: Rect2i in TREE_MARKED_RECTS:
		for y: int in range(rect.position.y, rect.end.y):
			var run := 0
			for x: int in range(rect.position.x, rect.end.x):
				var color := _image.get_pixel(x, y)
				var rgb_key := Color(color.r, color.g, color.b).to_rgba32()
				run = run + 1 if color.a > 0.0 and dirty_dark_green.has(rgb_key) else 0
				max_dirty_horizontal_run = maxi(max_dirty_horizontal_run, run)
		for x: int in range(rect.position.x, rect.end.x):
			var run := 0
			for y: int in range(rect.position.y, rect.end.y):
				var color := _image.get_pixel(x, y)
				var rgb_key := Color(color.r, color.g, color.b).to_rgba32()
				run = run + 1 if color.a > 0.0 and dirty_dark_green.has(rgb_key) else 0
				max_dirty_vertical_run = maxi(max_dirty_vertical_run, run)
	var fluorescent_hull_holes := 0
	for x: int in LOGICAL_SIZE.x:
		var top := -1
		var fluorescent_bottom := -1
		for y: int in range(AURORA_MAX_Y + 1):
			var color := _image.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			if top < 0:
				top = y
			var rgb_key := Color(color.r, color.g, color.b).to_rgba32()
			if fluorescent.has(rgb_key):
				fluorescent_bottom = y
		if top < 0 or fluorescent_bottom <= top:
			continue
		for y: int in range(top, fluorescent_bottom + 1):
			fluorescent_hull_holes += int(_image.get_pixel(x, y).a <= 0.0)
	var marked_slot_holes := _count_marked_vertical_holes()
	var scene8_4_curve := _probe_scene8_4_bottom_curve()
	var left_rim_non_fluorescent_pixels := _count_left_rim_non_fluorescent_pixels(
			fluorescent)
	var green_tail: Dictionary[int, bool] = {}
	for hex_color: String in GREEN_TAIL_COLORS:
		green_tail[Color(hex_color).to_rgba32()] = true
	var right_green_tail_pixels := 0
	for y: int in range(
			RIGHT_TAIL_RECOLOR_RECT.position.y, RIGHT_TAIL_RECOLOR_RECT.end.y):
		for x: int in range(
				RIGHT_TAIL_RECOLOR_RECT.position.x, RIGHT_TAIL_RECOLOR_RECT.end.x):
			var color := _image.get_pixel(x, y)
			var rgb_key := Color(color.r, color.g, color.b).to_rgba32()
			right_green_tail_pixels += int(color.a > 0.0 and green_tail.has(rgb_key))
	return {
		"passed": max_dirty_horizontal_run <= 3
				and max_dirty_vertical_run <= 3
				and fluorescent_hull_holes == 0
				and marked_slot_holes == 0
				and left_rim_non_fluorescent_pixels == 0
				and right_green_tail_pixels == 0
				and bool(scene8_4_curve["passed"]),
		"max_dirty_horizontal_run": max_dirty_horizontal_run,
		"max_dirty_vertical_run": max_dirty_vertical_run,
		"fluorescent_hull_holes": fluorescent_hull_holes,
		"scene8_3_marked_slot_holes": marked_slot_holes,
		"left_rim_non_fluorescent_pixels": left_rim_non_fluorescent_pixels,
		"right_green_tail_pixels": right_green_tail_pixels,
		"scene8_4_curve": scene8_4_curve,
	}


func _count_left_rim_non_fluorescent_pixels(
		fluorescent: Dictionary[int, bool]) -> int:
	var invalid_pixels := 0
	for x: int in range(74, 101):
		var bottom := -1
		for y: int in range(AURORA_MAX_Y + 1):
			if _image.get_pixel(x, y).a > 0.0:
				bottom = y
		if bottom < 0:
			invalid_pixels += 1
			continue
		var color := _image.get_pixel(x, bottom)
		var rgb_key := Color(color.r, color.g, color.b).to_rgba32()
		invalid_pixels += int(not fluorescent.has(rgb_key))
	return invalid_pixels


func _count_marked_vertical_holes() -> int:
	var holes := 0
	for rect: Rect2i in SCENE8_3_CUTOUT_RECTS:
		for x: int in range(rect.position.x, rect.end.x):
			var top := -1
			var bottom := -1
			var scan_top := maxi(rect.position.y - 4, 0)
			var scan_bottom := mini(rect.end.y + 4, AURORA_MAX_Y + 1)
			for y: int in range(scan_top, scan_bottom):
				if _image.get_pixel(x, y).a <= 0.0:
					continue
				if top < 0:
					top = y
				bottom = y
			if top < 0 or bottom <= top:
				continue
			for y: int in range(maxi(rect.position.y, top), mini(rect.end.y, bottom + 1)):
				holes += int(_image.get_pixel(x, y).a <= 0.0)
	return holes


func _probe_scene8_4_bottom_curve() -> Dictionary:
	var holes_above_curve := 0
	var pixels_below_curve := 0
	var maximum_step := 0
	var previous_bottom := -1
	for x: int in range(82, 101):
		var bottom := _left_closure_arc_bottom(x)
		var top := _column_top(x)
		for y: int in range(top, bottom + 1):
			holes_above_curve += int(_image.get_pixel(x, y).a <= 0.0)
		for y: int in range(bottom + 1, AURORA_MAX_Y + 1):
			pixels_below_curve += int(_image.get_pixel(x, y).a > 0.0)
	for x: int in range(169, 256):
		var bottom := _scene8_4_right_bottom(x)
		if previous_bottom >= 0:
			maximum_step = maxi(maximum_step, absi(bottom - previous_bottom))
		previous_bottom = bottom
		var top := _column_top(x)
		for y: int in range(top, bottom + 1):
			holes_above_curve += int(_image.get_pixel(x, y).a <= 0.0)
		for y: int in range(bottom + 1, AURORA_MAX_Y + 1):
			pixels_below_curve += int(_image.get_pixel(x, y).a > 0.0)
	return {
		"passed": holes_above_curve == 0 and pixels_below_curve == 0
				and maximum_step <= 2,
		"holes_above_curve": holes_above_curve,
		"pixels_below_curve": pixels_below_curve,
		"maximum_step": maximum_step,
	}


func _scene8_4_right_bottom(x: int) -> int:
	for index: int in range(SCENE8_4_RIGHT_CURVE_POINTS.size() - 1):
		var start := SCENE8_4_RIGHT_CURVE_POINTS[index]
		var finish := SCENE8_4_RIGHT_CURVE_POINTS[index + 1]
		if x > int(finish.x):
			continue
		var t := float(x - start.x) / maxf(float(finish.x - start.x), 1.0)
		return int(roundf(lerpf(start.y, finish.y, t)))
	return SCENE8_4_RIGHT_CURVE_POINTS[SCENE8_4_RIGHT_CURVE_POINTS.size() - 1].y


func _left_closure_arc_bottom(x: int) -> int:
	for index: int in range(LEFT_CLOSURE_ARC_POINTS.size() - 1):
		var start := LEFT_CLOSURE_ARC_POINTS[index]
		var finish := LEFT_CLOSURE_ARC_POINTS[index + 1]
		if x > finish.x:
			continue
		var t := float(x - start.x) / maxf(float(finish.x - start.x), 1.0)
		return int(roundf(lerpf(start.y, finish.y, t)))
	return LEFT_CLOSURE_ARC_POINTS[LEFT_CLOSURE_ARC_POINTS.size() - 1].y


func _column_top(x: int) -> int:
	for y: int in range(AURORA_MAX_Y + 1):
		if _image.get_pixel(x, y).a > 0.0:
			return y
	return 0


func _probe_pixel_distribution() -> Dictionary:
	var accepted_palette: Dictionary[int, bool] = {}
	for hex_color: String in PALETTE:
		accepted_palette[Color(hex_color).to_rgba32()] = true
	var counts: Dictionary[int, int] = {}
	var palette_mismatches := 0
	var non_binary_alpha := 0
	for y: int in LOGICAL_SIZE.y:
		for x: int in LOGICAL_SIZE.x:
			var color := _image.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			non_binary_alpha += int(color.a8 != 255)
			var rgb_key := Color(color.r, color.g, color.b).to_rgba32()
			counts[rgb_key] = counts.get(rgb_key, 0) + 1
			palette_mismatches += int(not accepted_palette.has(rgb_key))
	var smallest_role := 8617
	var largest_role := 0
	for count: int in counts.values():
		smallest_role = mini(smallest_role, count)
		largest_role = maxi(largest_role, count)
	return {
		"passed": counts.size() == PALETTE.size()
				and palette_mismatches == 0 and non_binary_alpha == 0
				and smallest_role >= 20 and largest_role <= 2200,
		"unique_colors": counts.size(),
		"palette_mismatches": palette_mismatches,
		"non_binary_alpha": non_binary_alpha,
		"smallest_color_role": smallest_role,
		"largest_color_role": largest_role,
	}


func _probe_full_curtain_motion() -> Dictionary:
	var texture_path := _aurora.texture.resource_path
	var shader_path := _motion_material.shader.resource_path
	var logical_size := _motion_material.get_shader_parameter("logical_size") as Vector2
	var motion_floor := float(_motion_material.get_shader_parameter("motion_floor"))
	var sway_x := float(_motion_material.get_shader_parameter("sway_x_pixels"))
	var sway_y := float(_motion_material.get_shader_parameter("sway_y_pixels"))
	var energy_strength := float(_motion_material.get_shader_parameter("energy_strength"))
	var primary_cycle := float(_motion_material.get_shader_parameter("primary_cycle_sec"))
	var secondary_cycle := float(_motion_material.get_shader_parameter(
			"secondary_cycle_sec"))
	var body_opacity_top := float(_motion_material.get_shader_parameter(
			"body_opacity_top"))
	var body_opacity_bottom := float(_motion_material.get_shader_parameter(
			"body_opacity_bottom"))
	var halo_strength := float(_motion_material.get_shader_parameter("halo_strength"))
	var shader_source := FileAccess.get_file_as_string(MOTION_SHADER_PATH)
	var occupied_by_band := PackedInt32Array()
	var moving_by_band := PackedInt32Array()
	var energy_changing_by_band := PackedInt32Array()
	occupied_by_band.resize(8)
	moving_by_band.resize(8)
	energy_changing_by_band.resize(8)
	var maximum_short_delta := Vector2.ZERO
	var maximum_long_delta := Vector2.ZERO
	for y: int in range(AURORA_MAX_Y + 1):
		for x: int in LOGICAL_SIZE.x:
			if _image.get_pixel(x, y).a <= 0.0:
				continue
			var band := mini(x * 8 / LOGICAL_SIZE.x, 7)
			occupied_by_band[band] += 1
			var pixel := Vector2(float(x) + 0.5, float(y) + 0.5)
			var at_start := _motion_displacement(pixel, 0.0)
			var at_short := _motion_displacement(pixel, 1.0)
			var at_later := _motion_displacement(pixel, 10.0)
			var short_delta := at_short - at_start
			var long_delta := at_later - at_start
			moving_by_band[band] += int(long_delta.length() >= 0.50)
			energy_changing_by_band[band] += int(
					absf(_motion_energy(pixel, 10.0) - _motion_energy(pixel, 0.0)) >= 0.12)
			maximum_short_delta.x = maxf(maximum_short_delta.x, absf(short_delta.x))
			maximum_short_delta.y = maxf(maximum_short_delta.y, absf(short_delta.y))
			maximum_long_delta.x = maxf(maximum_long_delta.x, absf(long_delta.x))
			maximum_long_delta.y = maxf(maximum_long_delta.y, absf(long_delta.y))
	var moving_ratios: Array[float] = []
	var energy_ratios: Array[float] = []
	var every_band_moves := true
	var every_band_changes_energy := true
	for band: int in range(8):
		var count := maxi(occupied_by_band[band], 1)
		var moving_ratio := float(moving_by_band[band]) / float(count)
		var energy_ratio := float(energy_changing_by_band[band]) / float(count)
		moving_ratios.append(moving_ratio)
		energy_ratios.append(energy_ratio)
		every_band_moves = every_band_moves and moving_ratio >= 0.60
		every_band_changes_energy = every_band_changes_energy and energy_ratio >= 0.20
	var display_scale := Vector2(
			(1920.0 + _aurora.offset_right - _aurora.offset_left) / logical_size.x,
			(1080.0 + _aurora.offset_bottom - _aurora.offset_top) / logical_size.y)
	var maximum_short_screen_delta := maximum_short_delta * display_scale
	var maximum_long_screen_delta := maximum_long_delta * display_scale
	return {
		"passed": texture_path == AURORA_PATH
				and _aurora.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
				and shader_path == MOTION_SHADER_PATH
				and _motion_material.resource_local_to_scene
				and logical_size == Vector2(LOGICAL_SIZE)
				and motion_floor >= 0.60
				and primary_cycle >= 24.0 and secondary_cycle >= 34.0
				and sway_x >= 1.4 and sway_x <= 2.0
				and sway_y >= 0.8 and sway_y <= 1.3
				and energy_strength >= 0.10 and energy_strength <= 0.18
				and body_opacity_top >= 0.68 and body_opacity_top <= 0.78
				and body_opacity_bottom >= 0.84 and body_opacity_bottom <= 0.92
				and halo_strength >= 0.08 and halo_strength <= 0.20
				and every_band_moves and every_band_changes_energy
				and maximum_short_screen_delta.x <= 5.0
				and maximum_short_screen_delta.y <= 3.0
				and maximum_long_screen_delta.x >= 12.0
				and maximum_long_screen_delta.y >= 6.0
				and shader_source.contains("TIME")
				and shader_source.contains("diagnostic_time_sec")
				and shader_source.contains("floor(source_px + vec2(0.5))")
				and not ResourceLoader.exists(RETIRED_SHADER_PATH),
		"texture_path": texture_path,
		"nearest_filter": _aurora.texture_filter,
		"motion_shader_path": shader_path,
		"motion_floor": motion_floor,
		"moving_ratios_by_eighth": moving_ratios,
		"energy_ratios_by_eighth": energy_ratios,
		"maximum_short_screen_delta": maximum_short_screen_delta,
		"maximum_long_screen_delta": maximum_long_screen_delta,
		"body_opacity_range": Vector2(body_opacity_top, body_opacity_bottom),
		"halo_strength": halo_strength,
		"retired_shader_removed": not ResourceLoader.exists(RETIRED_SHADER_PATH),
	}


func _motion_displacement(pixel: Vector2, time_sec: float) -> Vector2:
	var logical_size := _motion_material.get_shader_parameter("logical_size") as Vector2
	var curtain_height := float(_motion_material.get_shader_parameter(
			"curtain_height_pixels"))
	var primary_cycle := float(_motion_material.get_shader_parameter("primary_cycle_sec"))
	var secondary_cycle := float(_motion_material.get_shader_parameter(
			"secondary_cycle_sec"))
	var sway_x := float(_motion_material.get_shader_parameter("sway_x_pixels"))
	var sway_y := float(_motion_material.get_shader_parameter("sway_y_pixels"))
	var motion_floor := float(_motion_material.get_shader_parameter("motion_floor"))
	var depth := clampf(pixel.y / maxf(curtain_height, 1.0), 0.0, 1.0)
	var participation := lerpf(motion_floor, 1.0, depth)
	var phase_x := pixel.x / logical_size.x * TAU
	var primary_phase := time_sec * TAU / maxf(primary_cycle, 0.001)
	var secondary_phase := time_sec * TAU / maxf(secondary_cycle, 0.001)
	var broad_sway := sin(primary_phase + phase_x * 1.35 + depth * 0.65)
	var folded_sway := sin(-secondary_phase + phase_x * 2.85 - depth * 1.70)
	var broad_lift := sin(primary_phase * 0.82 - phase_x * 1.10 + depth * 1.35)
	var folded_lift := sin(
			secondary_phase * 1.14 + phase_x * 2.10 + depth * 2.25)
	return Vector2(
			sway_x * participation * (broad_sway * 0.68 + folded_sway * 0.32),
			sway_y * participation * (broad_lift * 0.62 + folded_lift * 0.38))


func _motion_energy(pixel: Vector2, time_sec: float) -> float:
	var logical_size := _motion_material.get_shader_parameter("logical_size") as Vector2
	var curtain_height := float(_motion_material.get_shader_parameter(
			"curtain_height_pixels"))
	var energy_cycle := float(_motion_material.get_shader_parameter("energy_cycle_sec"))
	var depth := clampf(pixel.y / maxf(curtain_height, 1.0), 0.0, 1.0)
	var phase_x := pixel.x / logical_size.x * TAU
	var energy_phase := time_sec * TAU / maxf(energy_cycle, 0.001)
	var energy_a := 0.5 + 0.5 * sin(
			energy_phase - phase_x * 1.35 + depth * 0.70)
	var energy_b := 0.5 + 0.5 * sin(
			energy_phase * 0.61 + phase_x * 2.0 - depth)
	return energy_a * 0.68 + energy_b * 0.32


func _probe_continuous_reflection() -> Dictionary:
	var start_depth := float(_reflection_material.get_shader_parameter(
			"reflection_start_depth"))
	var end_depth := float(_reflection_material.get_shader_parameter(
			"reflection_end_depth"))
	var source_top := float(_reflection_material.get_shader_parameter(
			"reflection_source_top_y"))
	var source_bottom := float(_reflection_material.get_shader_parameter(
			"reflection_source_bottom_y"))
	var stretch := float(_reflection_material.get_shader_parameter(
			"reflection_horizontal_stretch"))
	var reflection_strength := float(_reflection_material.get_shader_parameter(
			"reflection_strength"))
	var reflection_floor := float(_reflection_material.get_shader_parameter(
			"reflection_floor"))
	var viewport_height := 1080.0
	var aurora_height := viewport_height \
			+ _aurora.offset_bottom - _aurora.offset_top
	var active_bins := 0
	var sampled_counts: Array[int] = []
	for bin_index: int in range(9):
		var depth := lerpf(start_depth, end_depth, float(bin_index) / 8.0)
		var depth_t := (depth - start_depth) / (end_depth - start_depth)
		var screen_source_y := lerpf(source_bottom, source_top, depth_t)
		var texture_y := (
				screen_source_y * viewport_height - _aurora.offset_top) \
				/ aurora_height
		var source_row := clampi(
				int(floorf(texture_y * float(LOGICAL_SIZE.y))),
				0, LOGICAL_SIZE.y - 1)
		var active_count := 0
		for x: int in LOGICAL_SIZE.x:
			var screen_x := (float(x) + 0.5) / float(LOGICAL_SIZE.x)
			var source_x := 0.5 + (screen_x - 0.5) / stretch
			var source_column := clampi(
					int(floorf(source_x * float(LOGICAL_SIZE.x))),
					0, LOGICAL_SIZE.x - 1)
			active_count += int(
					_image.get_pixel(source_column, source_row).a > 0.0)
		sampled_counts.append(active_count)
		active_bins += int(active_count > 0)
	return {
		"passed": active_bins >= 8 and stretch >= 1.02 and stretch <= 1.18
				and start_depth >= 0.06 and start_depth <= 0.10
				and end_depth >= 0.84 and end_depth <= 0.90
				and source_top >= 0.02 and source_top <= 0.06
				and source_bottom >= 0.33 and source_bottom <= 0.37
				and reflection_strength >= 0.60
				and reflection_floor >= 0.18
				and end_depth < float(_reflection_material.get_shader_parameter(
						"reflection_coverage_depth")),
		"active_depth_bins": active_bins,
		"sampled_counts": sampled_counts,
		"horizontal_stretch": stretch,
		"reflection_strength": reflection_strength,
		"reflection_floor": reflection_floor,
	}
