extends Control

## h11「影狩」固定像素逐帧撕咬。
## 所有形变与像素块都已固化在 Sprite Sheet 中，运行时只切换帧。

signal bite_closed
signal effect_finished

const SHEET_PATH := "res://assets/effects/h11_bite/h11_bite_sheet.png"
const SHEET_TEXTURE: Texture2D = preload(SHEET_PATH)
const CELL_SIZE := Vector2i(208, 208)
const FRAME_COUNT := 8
const OPEN_PIXEL_BLOCK := 1
const CLOSED_PIXEL_BLOCK := 1
const CLOSED_FRAME := 6
const VANISH_FRAME := 7
const CLOSE_FRAME_WEIGHTS: Array[float] = [0.08, 0.10, 0.25, 0.25, 0.18, 0.14]
const DEFAULT_CLOSE_DURATION := 0.22
const DEFAULT_IMPACT_HOLD := 0.04
const DEFAULT_RELEASE_DURATION := 0.08
const DARK_OUTLINE := Color("08070b")
const BLACK_BODY := Color("17131d")
const ENERGY_HIGHLIGHT := Color("5b4968")

var close_duration: float = DEFAULT_CLOSE_DURATION
var impact_hold: float = DEFAULT_IMPACT_HOLD
var release_duration: float = DEFAULT_RELEASE_DURATION

var _sprite: AnimatedSprite2D
var _playing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 86
	z_as_relative = false
	_build_sprite()
	_center_sprite()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_center_sprite()


func configure(close_seconds: float, hold_seconds: float, release_seconds: float) -> void:
	close_duration = maxf(close_seconds, 0.01)
	impact_hold = maxf(hold_seconds, 0.0)
	release_duration = maxf(release_seconds, 0.01)


func play() -> void:
	if _playing:
		return
	_playing = true
	modulate = Color.WHITE
	for frame_index in CLOSED_FRAME:
		_sprite.frame = frame_index
		await get_tree().create_timer(
				close_duration * CLOSE_FRAME_WEIGHTS[frame_index]).timeout
		if not is_instance_valid(self):
			return
	_sprite.frame = CLOSED_FRAME
	bite_closed.emit()

	if impact_hold > 0.0:
		await get_tree().create_timer(impact_hold).timeout
	if not is_instance_valid(self):
		return
	_sprite.frame = VANISH_FRAME
	await get_tree().create_timer(release_duration).timeout
	if not is_instance_valid(self):
		return
	effect_finished.emit()
	queue_free()


func _build_sprite() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("bite")
	frames.set_animation_loop("bite", false)
	for frame_index in FRAME_COUNT:
		var atlas := AtlasTexture.new()
		atlas.atlas = SHEET_TEXTURE
		atlas.region = Rect2(frame_index * CELL_SIZE.x, 0, CELL_SIZE.x, CELL_SIZE.y)
		frames.add_frame("bite", atlas)
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "PixelBiteFrames"
	_sprite.sprite_frames = frames
	_sprite.animation = "bite"
	_sprite.frame = 0
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)


func _center_sprite() -> void:
	if is_instance_valid(_sprite):
		_sprite.position = (size * 0.5).round()


func debug_sprite_sheet_profile() -> Dictionary:
	return {
		path = SHEET_PATH,
		frame_count = FRAME_COUNT,
		cell_size = CELL_SIZE,
		sheet_size = Vector2i(CELL_SIZE.x * FRAME_COUNT, CELL_SIZE.y),
		open_pixel_block = OPEN_PIXEL_BLOCK,
		closed_pixel_block = CLOSED_PIXEL_BLOCK,
		mixed_native_pixel_grids = false,
		generated_from_references = true,
		runtime_shader_pixelation = false,
	}


func debug_playback_profile() -> Dictionary:
	return {
		closed_frame = CLOSED_FRAME,
		vanish_frame = VANISH_FRAME,
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST,
		appear_scale = 1.0,
		baked_fragment_release = false,
		blank_release_frame = true,
		close_frame_weights = CLOSE_FRAME_WEIGHTS.duplicate(),
		appearance_share = CLOSE_FRAME_WEIGHTS[0] + CLOSE_FRAME_WEIGHTS[1],
		anticipation_share = CLOSE_FRAME_WEIGHTS[2] + CLOSE_FRAME_WEIGHTS[3]
				+ CLOSE_FRAME_WEIGHTS[4],
		snap_share = CLOSE_FRAME_WEIGHTS[5],
		default_close_duration = DEFAULT_CLOSE_DURATION,
		default_impact_hold = DEFAULT_IMPACT_HOLD,
		default_release_duration = DEFAULT_RELEASE_DURATION,
	}


func debug_palette_filter_profile() -> Dictionary:
	return {
		active = false,
		shader_path = "",
		strength = 0.0,
		geometry_affecting = false,
		alpha_passthrough = true,
		material_cue = "shadow_energy",
		compressed_specular_contrast = true,
		dark_outline = DARK_OUTLINE,
		black_body = BLACK_BODY,
		energy_highlight = ENERGY_HIGHLIGHT,
	}


func debug_source_profile() -> Dictionary:
	return {
		reference_open_path = "res://res/open_pixel.png",
		reference_closed_path = "res://res/bite_pixel.png",
		runtime_open_path = "res://assets/effects/h11_bite/open_pixel.png",
		runtime_closed_path = "res://assets/effects/h11_bite/bite_pixel.png",
		generator_path = "res://tools/generate_h11_bite_sheet.gd",
		source_uv_locked = true,
		horizontal_mirror = false,
		used_bounds_reframed = false,
		silhouette_union = false,
		procedural_tooth_redraw = false,
		direct_native_pixel_copy = true,
		tooth_gap_expansion_pixels = 0,
		impact_frame_reference = "res://res/bite_pixel.png",
		open_frame_reference = "res://res/open_pixel.png",
		release_frame_reference = "none",
		release_frame_blank = true,
		approved_static_sheet = \
				"res://assets/effects/h11_bite/h11_bite_stage1_sheet.png",
	}


static func audit_sheet_palette(sheet: Image) -> Dictionary:
	var colors := {}
	var warm_pixels := 0
	var opaque_pixels := 0
	var semi_transparent_pixels := 0
	var accent_pixels := 0
	for y in sheet.get_height():
		for x in sheet.get_width():
			var color: Color = sheet.get_pixel(x, y)
			if color.a <= 0.01:
				continue
			opaque_pixels += 1
			if color.a < 0.99:
				semi_transparent_pixels += 1
			var key := "%02x%02x%02x" % [
				roundi(color.r * 255.0), roundi(color.g * 255.0),
				roundi(color.b * 255.0)]
			colors[key] = true
			if color.is_equal_approx(ENERGY_HIGHLIGHT):
				accent_pixels += 1
			if color.r > color.g + 0.03 and color.r > color.b + 0.03:
				warm_pixels += 1
	var color_names: Array = colors.keys()
	color_names.sort()
	return {
		opaque_color_count = colors.size(),
		colors = color_names,
		warm_pixels = warm_pixels,
		opaque_pixels = opaque_pixels,
		semi_transparent_pixels = semi_transparent_pixels,
		accent_ratio = float(accent_pixels) / maxf(float(opaque_pixels), 1.0),
	}


static func audit_sheet_geometry(sheet: Image) -> Dictionary:
	var metrics: Array[Dictionary] = []
	for frame_index in FRAME_COUNT:
		var region: Image = sheet.get_region(Rect2i(
				frame_index * CELL_SIZE.x, 0, CELL_SIZE.x, CELL_SIZE.y))
		metrics.append(_audit_frame_geometry(region))
	var max_center_error := 0.0
	var max_jaw_delta_x := 0.0
	var max_adjacent_center_jump := 0.0
	for frame_index in CLOSED_FRAME + 1:
		var frame_metric: Dictionary = metrics[frame_index]
		max_center_error = maxf(max_center_error,
				absf(float(frame_metric["center_x"]) - CELL_SIZE.x * 0.5))
		if frame_index < CLOSED_FRAME:
			max_jaw_delta_x = maxf(max_jaw_delta_x,
					absf(float(frame_metric["top_center_x"])
							- float(frame_metric["bottom_center_x"])))
		if frame_index > 0:
			max_adjacent_center_jump = maxf(max_adjacent_center_jump,
					absf(float(frame_metric["center_x"])
							- float((metrics[frame_index - 1] as Dictionary)["center_x"])))
	var open_width: int = int((metrics[2] as Dictionary)["width"])
	var closed_width: int = int((metrics[CLOSED_FRAME] as Dictionary)["width"])
	return {
		frames = metrics,
		max_center_error = max_center_error,
		max_jaw_delta_x = max_jaw_delta_x,
		max_adjacent_center_jump = max_adjacent_center_jump,
		open_width = open_width,
		closed_width = closed_width,
		closed_to_open_width = float(closed_width) / maxf(float(open_width), 1.0),
	}


static func audit_tooth_structure(sheet: Image) -> Dictionary:
	var open_frame: Image = sheet.get_region(Rect2i(
			2 * CELL_SIZE.x, 0, CELL_SIZE.x, CELL_SIZE.y))
	var release_frame: Image = sheet.get_region(Rect2i(
			VANISH_FRAME * CELL_SIZE.x, 0, CELL_SIZE.x, CELL_SIZE.y))
	# 新版牙齿由透明单格缝直接分开，按 alpha 统计即可，不再依赖亮度。
	var all_open_components: Array[Dictionary] = _collect_solid_components(open_frame, 0.0)
	var open_components: Array[Dictionary] = []
	var open_pixels := 0
	var largest_open := 0
	for component: Dictionary in all_open_components:
		var area: int = int(component["area"])
		if area < 12:
			continue
		open_components.append(component)
		open_pixels += area
		largest_open = maxi(largest_open, area)
	var release_powder_components := 0
	for component: Dictionary in _collect_solid_components(release_frame, 0.0):
		if int(component["area"]) <= CLOSED_PIXEL_BLOCK * CLOSED_PIXEL_BLOCK:
			release_powder_components += 1
	return {
		open_component_count = open_components.size(),
		largest_open_component_ratio = float(largest_open) \
				/ maxf(float(open_pixels), 1.0),
		release_powder_components = release_powder_components,
	}


static func _collect_solid_components(frame: Image,
		minimum_luma: float) -> Array[Dictionary]:
	var width: int = frame.get_width()
	var height: int = frame.get_height()
	var visited := PackedByteArray()
	visited.resize(width * height)
	var components: Array[Dictionary] = []
	const OFFSETS: Array[Vector2i] = [
		Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
	]
	for start_y in height:
		for start_x in width:
			var start_index: int = start_y * width + start_x
			if visited[start_index] != 0 \
					or not _is_component_pixel(frame.get_pixel(start_x, start_y),
							minimum_luma):
				continue
			var queue: Array[Vector2i] = [Vector2i(start_x, start_y)]
			var queue_index := 0
			visited[start_index] = 1
			var area := 0
			var min_x := start_x
			var max_x := start_x
			var min_y := start_y
			var max_y := start_y
			while queue_index < queue.size():
				var point: Vector2i = queue[queue_index]
				queue_index += 1
				area += 1
				min_x = mini(min_x, point.x)
				max_x = maxi(max_x, point.x)
				min_y = mini(min_y, point.y)
				max_y = maxi(max_y, point.y)
				for offset: Vector2i in OFFSETS:
					var next: Vector2i = point + offset
					if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height:
						continue
					var next_index: int = next.y * width + next.x
					if visited[next_index] != 0 \
							or not _is_component_pixel(frame.get_pixel(next.x, next.y),
									minimum_luma):
						continue
					visited[next_index] = 1
					queue.append(next)
			components.append({
				area = area,
				min_x = min_x,
				max_x = max_x,
				min_y = min_y,
				max_y = max_y,
				center_y = (min_y + max_y) * 0.5,
			})
	return components


static func _is_component_pixel(color: Color, minimum_luma: float) -> bool:
	if color.a < 0.99:
		return false
	var luma: float = color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
	return luma >= minimum_luma


static func _audit_frame_geometry(frame: Image) -> Dictionary:
	var count := 0
	var sum_x := 0.0
	var top_count := 0
	var top_sum_x := 0.0
	var bottom_count := 0
	var bottom_sum_x := 0.0
	var min_x := frame.get_width()
	var max_x := -1
	for y in frame.get_height():
		for x in frame.get_width():
			if frame.get_pixel(x, y).a <= 0.01:
				continue
			count += 1
			sum_x += x
			min_x = mini(min_x, x)
			max_x = maxi(max_x, x)
			if y < frame.get_height() * 0.5:
				top_count += 1
				top_sum_x += x
			else:
				bottom_count += 1
				bottom_sum_x += x
	var mass_center_x: float = sum_x / maxf(float(count), 1.0)
	var center_x: float = (min_x + max_x) * 0.5 if count > 0 else 0.0
	return {
		center_x = center_x,
		mass_center_x = mass_center_x,
		top_center_x = top_sum_x / maxf(float(top_count), 1.0),
		bottom_center_x = bottom_sum_x / maxf(float(bottom_count), 1.0),
		width = maxi(0, max_x - min_x + 1),
		opaque_pixels = count,
	}


static func audit_sheet_frames(sheet: Image) -> Array:
	var report: Array = []
	for frame_index in FRAME_COUNT:
		var region := sheet.get_region(Rect2i(
				frame_index * CELL_SIZE.x, 0, CELL_SIZE.x, CELL_SIZE.y))
		var opaque_pixels := 0
		for y in region.get_height():
			for x in region.get_width():
				if region.get_pixel(x, y).a > 0.01:
					opaque_pixels += 1
		report.append({
			opaque_pixels = opaque_pixels,
			hash = hash(region.get_data()),
		})
	return report
