extends Control

## Scene9-only distant bird flock. The generated master establishes the bird
## silhouette; the runtime uses a cleaned three-frame 5x3 hard-pixel strip.
## Every bird is drawn intact on the left mountain's source-pixel grid. The
## child draw order keeps the flock fully in front of the mountain; no mountain
## alpha mask is allowed to cut or temporarily hide bird pixels.

const BIRD_STRIP: Texture2D = preload(
		"res://assets/scenes/scene9/scene9_distant_bird_strip.png")
const SPAWN_TOP_LEFT := Vector2(61.0, 102.0)
const FRAME_SIZE := Vector2i(5, 3)
const FRAME_COUNT := 3
const BIRD_COUNT := 8
const WING_FPS := 6.0
const TOTAL_DURATION_SEC := 5.2
const OPACITY_FADE_DURATION_SEC := 1.0
const START_DELAYS := [0.0, 0.10, 0.20, 0.31, 0.44, 0.58, 0.73, 0.90]
const FLIGHT_DURATIONS := [3.55, 3.75, 3.90, 4.05, 4.15, 3.80, 4.30, 4.20]
const START_OFFSETS := [
	Vector2(-2.0, 1.0), Vector2(1.0, -1.0),
	Vector2(-1.0, 0.0), Vector2(2.0, 1.0),
	Vector2(0.0, -2.0), Vector2(-2.0, -1.0),
	Vector2(1.0, 1.0), Vector2(2.0, -2.0),
]
const FLIGHT_ENDPOINTS := [
	Vector2(127.0, 51.0), Vector2(143.0, 62.0),
	Vector2(117.0, 43.0), Vector2(153.0, 70.0),
	Vector2(132.0, 38.0), Vector2(160.0, 58.0),
	Vector2(139.0, 47.0), Vector2(151.0, 34.0),
]
const WING_PHASES := [0.0, 1.0, 2.0, 0.5, 1.5, 2.5, 0.75, 1.75]

var _frame_pixels: Array[Array] = []
var _flight_endpoints: Array[Vector2] = []
var _cloud_occluder_nodes: Array[CanvasItem] = []
var _cloud_coverage_lookup: Dictionary = {}
var _elapsed_sec := 0.0
var _active := false
var _play_count := 0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = false
	material = null
	_build_frame_pixels()
	_resolve_cloud_covered_endpoints()
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	_advance_animation(delta)


func _draw() -> void:
	if not _active:
		return
	for bird_index: int in BIRD_COUNT:
		var state := _bird_state(bird_index)
		if state.is_empty():
			continue
		_draw_bird(state)


func start_flock() -> bool:
	if _active or _frame_pixels.size() != FRAME_COUNT:
		return false
	_active = true
	_play_count += 1
	_elapsed_sec = 0.0
	visible = true
	set_process(true)
	queue_redraw()
	return true


func is_active() -> bool:
	return _active


func advance_for_testing(delta: float) -> void:
	_advance_animation(maxf(delta, 0.0))


func visible_birds_snapshot() -> Array:
	var result: Array = []
	for bird_index: int in BIRD_COUNT:
		var state := _bird_state(bird_index)
		if not state.is_empty():
			result.append(state)
	return result


func flight_endpoints_for_testing() -> Array:
	return _flight_endpoints.duplicate()


func visual_contract_snapshot() -> Dictionary:
	var parent_scale := Vector2.ONE
	var mountain := get_parent() as Control
	if mountain != null:
		parent_scale = mountain.scale.abs()
	return {
		"construction": "generated_master_hard_pixel_strip",
		"bird_count": BIRD_COUNT,
		"frame_count": FRAME_COUNT,
		"source_frame_size": FRAME_SIZE,
		"display_footprint_px": Vector2i(
				roundi(FRAME_SIZE.x * parent_scale.x),
				roundi(FRAME_SIZE.y * parent_scale.y)),
		"palette_color_count": _palette_color_count(),
		"hard_alpha_only": _strip_has_hard_alpha(),
		"minimum_frame_opaque_pixels": _minimum_frame_opaque_pixels(),
		"maximum_spawn_delay_seconds": START_DELAYS[BIRD_COUNT - 1],
		"duration_seconds": TOTAL_DURATION_SEC,
		"integer_source_positions": true,
		"socket_pixel_masking": false,
		"mountain_wide_pixel_occlusion": false,
		"whole_bird_mountain_occlusion": false,
		"always_in_front_of_mountain": true,
		"mountain_occlusion_strategy": "none_front_layer",
		"parent_draw_order": "after_parent_no_mask",
		"cloud_occlusion_by_draw_order": true,
		"retires_only_after_cloud_occlusion":
				endpoints_are_cloud_covered_for_testing(),
		"hard_cut_end": false,
		"cloud_occlusion_hold_seconds": 0.0,
		"opacity_fade_seconds": OPACITY_FADE_DURATION_SEC,
		"keeps_moving_during_fade": true,
		"minimum_fade_travel_source_px": _minimum_fade_travel_source_px(),
		"emergence_route": "diagonal_up_right_arc",
		"uses_particles": false,
		"uses_opacity_fade": true,
		"uses_blur": false,
		"repeatable_after_completion": true,
		"play_count": _play_count,
	}


func _build_frame_pixels() -> void:
	_frame_pixels.clear()
	var strip_image := BIRD_STRIP.get_image()
	if strip_image == null or strip_image.is_empty():
		return
	for frame_index: int in FRAME_COUNT:
		var pixels: Array = []
		for y: int in FRAME_SIZE.y:
			for x: int in FRAME_SIZE.x:
				var color := strip_image.get_pixel(
						frame_index * FRAME_SIZE.x + x, y)
				if color.a < 0.5:
					continue
				pixels.append({
					"offset": Vector2i(x, y),
					"color": Color(color.r, color.g, color.b, 1.0),
				})
		_frame_pixels.append(pixels)


func _bird_state(bird_index: int) -> Dictionary:
	var start_delay: float = START_DELAYS[bird_index]
	var local_elapsed := _elapsed_sec - start_delay
	if local_elapsed < 0.0:
		return {}
	var duration: float = FLIGHT_DURATIONS[bird_index]
	if local_elapsed >= duration:
		return {}
	var progress := clampf(local_elapsed / duration, 0.0, 1.0)
	var raw_position := _bird_position_at_progress(bird_index, progress)
	var fade_start := maxf(duration - OPACITY_FADE_DURATION_SEC, 0.0)
	var fade_progress := clampf(
			(local_elapsed - fade_start) / OPACITY_FADE_DURATION_SEC, 0.0, 1.0)
	var opacity := 1.0 - _smootherstep(fade_progress)
	var frame := posmod(
			floori(local_elapsed * WING_FPS + float(WING_PHASES[bird_index])),
			FRAME_COUNT)
	return {
		"index": bird_index,
		"position": raw_position.round(),
		"frame": frame,
		"progress": progress,
		"opacity": opacity,
	}


func _draw_bird(state: Dictionary) -> void:
	var position := state["position"] as Vector2
	var frame := int(state["frame"])
	var opacity := float(state["opacity"])
	var pixels: Array = _frame_pixels[frame]
	for pixel_variant: Variant in pixels:
		var pixel := pixel_variant as Dictionary
		var offset := pixel["offset"] as Vector2i
		var source_pixel := Vector2i(position) + offset
		var source_color := pixel["color"] as Color
		draw_rect(
				Rect2(Vector2(source_pixel), Vector2.ONE),
				Color(source_color.r, source_color.g, source_color.b, opacity), true)


func _advance_animation(delta: float) -> void:
	if not _active:
		return
	_elapsed_sec += delta
	if _elapsed_sec >= TOTAL_DURATION_SEC:
		_active = false
		visible = false
		set_process(false)
		queue_redraw()
		return
	queue_redraw()


func endpoints_are_cloud_covered_for_testing() -> bool:
	if _flight_endpoints.size() != BIRD_COUNT:
		return false
	for bird_index: int in BIRD_COUNT:
		if not _position_is_cloud_covered(_flight_endpoints[bird_index]):
			return false
	return true


func _bird_position_at_progress(bird_index: int, progress: float) -> Vector2:
	var start: Vector2 = SPAWN_TOP_LEFT + START_OFFSETS[bird_index]
	var end: Vector2 = _flight_endpoints[bird_index] \
			if _flight_endpoints.size() == BIRD_COUNT else FLIGHT_ENDPOINTS[bird_index]
	var clamped_progress := clampf(progress, 0.0, 1.0)
	var control := (start + end) * 0.5 \
			+ Vector2(5.0, -14.0 - float(bird_index))
	var inverse := 1.0 - clamped_progress
	return (inverse * inverse * start
			+ 2.0 * inverse * clamped_progress * control
			+ clamped_progress * clamped_progress * end)


func _minimum_fade_travel_source_px() -> float:
	var minimum_distance := INF
	for bird_index: int in BIRD_COUNT:
		var duration: float = FLIGHT_DURATIONS[bird_index]
		var fade_start_progress := clampf(
				(duration - OPACITY_FADE_DURATION_SEC) / duration, 0.0, 1.0)
		var fade_start := _bird_position_at_progress(
				bird_index, fade_start_progress)
		var fade_end := _bird_position_at_progress(bird_index, 1.0)
		minimum_distance = minf(minimum_distance, fade_start.distance_to(fade_end))
	return minimum_distance if is_finite(minimum_distance) else 0.0


func _smootherstep(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


func _resolve_cloud_covered_endpoints() -> void:
	_flight_endpoints.clear()
	_cloud_coverage_lookup.clear()
	_cloud_occluder_nodes = _cloud_occluders()
	for endpoint_variant: Variant in FLIGHT_ENDPOINTS:
		var preferred := endpoint_variant as Vector2
		var resolved := preferred
		var best_distance := INF
		for offset_y: int in range(-18, 111):
			for offset_x: int in range(-12, 49):
				var candidate := (preferred + Vector2(offset_x, offset_y)).round()
				if not _position_is_cloud_covered(candidate):
					continue
				if _flight_endpoints.size() < 4:
					var duplicates_prior_y := false
					for prior_endpoint: Vector2 in _flight_endpoints:
						if int(prior_endpoint.y) == int(candidate.y):
							duplicates_prior_y = true
							break
					if duplicates_prior_y:
						continue
				var distance := Vector2(offset_x, offset_y).length_squared()
				if distance < best_distance:
					best_distance = distance
					resolved = candidate
		_flight_endpoints.append(resolved)


func _position_is_cloud_covered(position: Vector2) -> bool:
	if _cloud_occluder_nodes.is_empty():
		_cloud_occluder_nodes = _cloud_occluders()
	if _cloud_occluder_nodes.is_empty() or _frame_pixels.is_empty():
		return false
	# Every authored opaque pixel in every wing frame must already be behind a
	# cloud pixel at retirement, so the animation never relies on a visibility cut.
	for frame_pixels: Array in _frame_pixels:
		for pixel_variant: Variant in frame_pixels:
			var pixel := pixel_variant as Dictionary
			var source_pixel := Vector2i(position) \
					+ (pixel["offset"] as Vector2i)
			if not _cloud_covers_source_pixel(source_pixel):
				return false
	return true


func _cloud_covers_source_pixel(source_pixel: Vector2i) -> bool:
	if _cloud_coverage_lookup.has(source_pixel):
		return bool(_cloud_coverage_lookup[source_pixel])
	var canvas_position := get_global_transform_with_canvas() \
			* (Vector2(source_pixel) + Vector2.ONE * 0.5)
	var covered := false
	for cloud: CanvasItem in _cloud_occluder_nodes:
		if bool(cloud.call(
				"has_stable_opaque_pixel_at_canvas_position", canvas_position)):
			covered = true
			break
	_cloud_coverage_lookup[source_pixel] = covered
	return covered


func _cloud_occluders() -> Array[CanvasItem]:
	var result: Array[CanvasItem] = []
	var stage := get_parent().get_parent()
	if stage == null:
		return result
	for node_name: String in ["DistantPixelCloudBank", "DistantPixelCloudBank2"]:
		var candidate := stage.get_node_or_null(node_name) as CanvasItem
		if (candidate != null
				and candidate.has_method("has_opaque_pixel_at_canvas_position")):
			result.append(candidate)
	return result


func _strip_has_hard_alpha() -> bool:
	var image := BIRD_STRIP.get_image()
	if image == null or image.is_empty():
		return false
	for y: int in image.get_height():
		for x: int in image.get_width():
			var alpha := image.get_pixel(x, y).a
			if alpha > 0.0 and alpha < 1.0:
				return false
	return true


func _palette_color_count() -> int:
	var colors: Dictionary = {}
	var image := BIRD_STRIP.get_image()
	if image == null or image.is_empty():
		return 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a >= 0.5:
				colors[color.to_rgba32()] = true
	return colors.size()


func _minimum_frame_opaque_pixels() -> int:
	var minimum := FRAME_SIZE.x * FRAME_SIZE.y
	for pixels: Array in _frame_pixels:
		minimum = mini(minimum, pixels.size())
	return minimum if not _frame_pixels.is_empty() else 0
