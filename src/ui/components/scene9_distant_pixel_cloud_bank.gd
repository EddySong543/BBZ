@tool
extends TextureRect

## Scene9-only authored pixel cloud. A single code-blueprint copy is placed in
## transparent padding. Every animated frame is an integer-coordinate remap of
## that cleaned RGBA source: no tiling, generated colors, overlay shading, blur,
## or spritesheet. The source pixels and upper silhouette breathe outward from
## the visual center while the terrain-facing bottom remains exact and immobile.

const CloudBlueprint := preload(
		"res://src/ui/components/scene9_cloud_blueprint.gd")
const CLOUD_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene9_pixel_cloud_motion.gdshader")
const CANVAS_SIZE := Vector2i(592, 136)
const CORE_ORIGIN_X := 92
const SCREEN_PIXEL_SIZE := 4
const LEFT_BOTTOM_SPUR_RECT := Rect2i(45, 118, 34, 5)
const ORANGE_PROTECTED_RECT := Rect2i(37, 82, 46, 20)
const MARKED_LEFT_HORIZON_ANNOTATION := Rect2i(37, 112, 44, 6)
const MARKED_LEFT_HORIZON_CLEANUP := Rect2i(37, 113, 44, 5)
const SOURCE_PHASE_PERIOD_PX := 48.0
const TEMPORAL_SAMPLES_PER_SOURCE_PHASE := 4.5
const DARK_LUMA_MAX := 220.0
const LIGHT_LUMA_MIN := 242.0
const RIPPLE_LIFETIME_SECONDS := 1.4
const RIPPLE_MAX_RADIUS_PX := 22.0
const RIPPLE_MAX_DISPLACEMENT_PX := 2
const RIPPLE_POOL_SIZE := 3

@export var impact_origin_path: NodePath
@export_range(12.0, 12.0, 1.0) var animation_fps: float = 12.0
@export_range(216, 216, 1) var loop_frame_count: int = 216
@export_range(2, 4, 1) var maximum_horizontal_displacement_px: int = 3
@export_range(2, 4, 1) var maximum_vertical_displacement_px: int = 3
@export_range(6, 12, 1) var bottom_lock_depth_px: int = 8
@export_range(8, 24, 1) var motion_blend_depth_px: int = 16

static var _shared_base_data: PackedByteArray = PackedByteArray()
static var _shared_source_data: PackedByteArray = PackedByteArray()
static var _shared_top_edge_y: PackedInt32Array = PackedInt32Array()
static var _shared_bottom_edge_y: PackedInt32Array = PackedInt32Array()
static var _shared_interior_depth: PackedByteArray = PackedByteArray()
static var _shared_base_texture: ImageTexture = null
static var _shared_metadata_texture: ImageTexture = null

var _base_data: PackedByteArray = PackedByteArray()
var _source_data: PackedByteArray = PackedByteArray()
var _top_edge_y: PackedInt32Array = PackedInt32Array()
var _bottom_edge_y: PackedInt32Array = PackedInt32Array()
var _interior_depth: PackedByteArray = PackedByteArray()
var _metadata_texture: ImageTexture = null
var _cloud_material: ShaderMaterial = null
var _motion_time: float = 0.0
var _visible_frame: int = -1
var _visible_interaction_tick: int = -1
var _ripple_active_slots: Array[bool] = [false, false, false]
var _ripple_ages: Array[float] = [0.0, 0.0, 0.0]
var _ripple_centers: Array[Vector2] = [
	Vector2.ZERO, Vector2.ZERO, Vector2.ZERO,
]
var _ripple_serials: Array[int] = [-1, -1, -1]
var _next_ripple_serial := 0
var _last_ripple_center := Vector2.ZERO
var _last_click_zone: int = -1


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_runtime_buffers()
	_configure_gpu_material()
	_apply_shader_state(0)
	set_process(true)


func _process(delta: float) -> void:
	_motion_time = fposmod(
			_motion_time + maxf(delta, 0.0),
			float(loop_frame_count) / maxf(animation_fps, 0.001))
	_advance_ripples(maxf(delta, 0.0))
	var frame: int = int(floor(_motion_time * animation_fps)) % loop_frame_count
	var interaction_tick := _combined_ripple_tick()
	if frame != _visible_frame or interaction_tick != _visible_interaction_tick:
		_apply_shader_state(frame)
		_visible_interaction_tick = interaction_tick


func pixel_source_size() -> Vector2i:
	return CANVAS_SIZE


func core_origin_x() -> int:
	return CORE_ORIGIN_X


func cycle_duration_seconds() -> float:
	return float(loop_frame_count) / maxf(animation_fps, 0.001)


func visible_frame_for_testing() -> int:
	return maxi(_visible_frame, 0)


func stable_opaque_source_pixel_for_zone(zone: int) -> Vector2i:
	_ensure_runtime_buffers()
	var source_width: int = CloudBlueprint.SOURCE_SIZE.x
	var zone_start := CORE_ORIGIN_X + int(floor(
			float(source_width) * float(zone) / 3.0))
	var zone_end := CORE_ORIGIN_X + int(floor(
			float(source_width) * float(zone + 1) / 3.0))
	for x: int in range(zone_start, zone_end):
		var bottom_y := _bottom_edge_y[x]
		if bottom_y < 0:
			continue
		for y: int in range(bottom_y, maxi(bottom_y - bottom_lock_depth_px, 0), -1):
			var candidate := Vector2i(x, y)
			if _base_data[(y * CANVAS_SIZE.x + x) * 4 + 3] == 0:
				continue
			var canvas_position := source_pixel_canvas_position(candidate)
			if canvas_position.x >= 0.0 and canvas_position.x < 1920.0 \
					and canvas_position.y >= 0.0 and canvas_position.y < 1080.0:
				return candidate
	return Vector2i(-1, -1)


func try_spawn_ripple_at_canvas_position(canvas_position: Vector2) -> bool:
	var source_pixel := _opaque_source_pixel_at_canvas_position(canvas_position)
	if source_pixel.x < 0:
		return false
	var selected_slot := _select_ripple_slot()
	_ripple_centers[selected_slot] = Vector2(source_pixel)
	_ripple_ages[selected_slot] = 0.0
	_ripple_active_slots[selected_slot] = true
	_ripple_serials[selected_slot] = _next_ripple_serial
	_next_ripple_serial += 1
	_last_ripple_center = Vector2(source_pixel)
	_last_click_zone = _zone_for_source_pixel(source_pixel)
	_apply_shader_state(maxi(_visible_frame, 0))
	return true


func advance_ripples_for_testing(delta: float) -> void:
	_advance_ripples(maxf(delta, 0.0))
	_apply_shader_state(maxi(_visible_frame, 0))


func has_opaque_pixel_at_canvas_position(canvas_position: Vector2) -> bool:
	return _opaque_source_pixel_at_canvas_position(canvas_position).x >= 0


func has_stable_opaque_pixel_at_canvas_position(canvas_position: Vector2) -> bool:
	_ensure_runtime_buffers()
	var destination_pixel := _canvas_position_to_source_pixel(canvas_position)
	if destination_pixel.x < 0:
		return false
	for frame: int in [0, 54, 108, 162, 215]:
		var source_pixel := _animated_source_pixel_for_frame(destination_pixel, frame)
		if source_pixel.x < 0:
			return false
		var byte_index := (source_pixel.y * CANVAS_SIZE.x + source_pixel.x) * 4
		if _base_data[byte_index + 3] == 0:
			return false
	return true


func last_click_zone() -> int:
	return _last_click_zone


func source_pixel_canvas_position(source_pixel: Vector2i) -> Vector2:
	var normalized := (Vector2(source_pixel) + Vector2.ONE * 0.5) \
			/ Vector2(CANVAS_SIZE)
	var local_position := normalized * size
	return get_global_transform_with_canvas() * local_position


func ripple_contract_snapshot() -> Dictionary:
	var active_ages: Array[float] = []
	for slot: int in RIPPLE_POOL_SIZE:
		if _ripple_active_slots[slot]:
			active_ages.append(_ripple_ages[slot])
	return {
		"active": not active_ages.is_empty(),
		"active_count": active_ages.size(),
		"active_ages_seconds": active_ages,
		"maximum_simultaneous_ripples": RIPPLE_POOL_SIZE,
		"same_region_overlap": true,
		"requires_alpha_hit": true,
		"lifetime_seconds": RIPPLE_LIFETIME_SECONDS,
		"maximum_radius_px": RIPPLE_MAX_RADIUS_PX,
		"maximum_displacement_px": RIPPLE_MAX_DISPLACEMENT_PX,
		"bottom_locked": true,
		"recovery_curve": "smootherstep_long_release",
		"renders_zero_amplitude_final_frame": true,
		"center_source_pixel": _last_ripple_center,
	}


func runtime_contract_snapshot() -> Dictionary:
	return {
		"animation_backend": "gpu_canvas_shader",
		"shader_path": _cloud_material.shader.resource_path \
				if _cloud_material != null and _cloud_material.shader != null else "",
		"recurring_cpu_frame_builds": 0,
		"recurring_texture_upload_bytes": 0,
		"base_texture_built_once": _shared_base_texture != null,
		"metadata_texture_built_once": _shared_metadata_texture != null,
		"material_local_to_scene": _cloud_material != null \
				and _cloud_material.resource_local_to_scene,
	}


func render_ripple_frame_for_testing(frame_index: int, phase: float) -> Image:
	_ensure_runtime_buffers()
	var center := _last_ripple_center
	if center == Vector2.ZERO:
		center = Vector2(
				CORE_ORIGIN_X + CloudBlueprint.SOURCE_SIZE.x * 0.5, 68.0)
	var data := _apply_ripple_to_data(
			_build_frame_data(frame_index), clampf(phase, 0.0, 1.0), center)
	return Image.create_from_data(
			CANVAS_SIZE.x, CANVAS_SIZE.y, false, Image.FORMAT_RGBA8, data)


func count_image_changed_pixels(first: Image, second: Image) -> int:
	var first_data := first.get_data()
	var second_data := second.get_data()
	var pixel_count := mini(
			first.get_width() * first.get_height(),
			second.get_width() * second.get_height())
	var changed := 0
	for pixel_index: int in pixel_count:
		var byte_index := pixel_index * 4
		if _pixel_differs(first_data, second_data, byte_index, byte_index):
			changed += 1
	return changed


func count_bottom_contour_differences(first: Image, second: Image) -> int:
	var metrics := _contour_change_metrics(first.get_data(), second.get_data())
	return int(metrics["bottom_changes"])


func count_palette_outliers(image: Image) -> int:
	var palette := _authored_palette()
	var data := image.get_data()
	var outliers := 0
	for pixel_index: int in range(data.size() / 4):
		var byte_index := pixel_index * 4
		if data[byte_index + 3] != 0 \
				and not palette.has(_rgb_key(data, byte_index)):
			outliers += 1
	return outliers


func count_alpha_silhouette_differences(first: Image, second: Image) -> int:
	var first_data := first.get_data()
	var second_data := second.get_data()
	var differences := 0
	for pixel_index: int in range(mini(
			first_data.size(), second_data.size()) / 4):
		var byte_index := pixel_index * 4 + 3
		if first_data[byte_index] != second_data[byte_index]:
			differences += 1
	return differences


func marked_horizon_screen_rect() -> Rect2:
	return _source_rect_screen_rect(MARKED_LEFT_HORIZON_ANNOTATION)


func orange_protected_screen_rect() -> Rect2:
	return _source_rect_screen_rect(ORANGE_PROTECTED_RECT)


func _source_rect_screen_rect(source_rect: Rect2i) -> Rect2:
	var local_start := Vector2(
			CORE_ORIGIN_X + source_rect.position.x,
			source_rect.position.y) * SCREEN_PIXEL_SIZE
	var local_end := Vector2(
			CORE_ORIGIN_X + source_rect.end.x,
			source_rect.end.y) * SCREEN_PIXEL_SIZE
	var global_start: Vector2 = get_global_transform() * local_start
	var global_end: Vector2 = get_global_transform() * local_end
	return Rect2(global_start, global_end - global_start)


func authored_signature() -> Dictionary:
	return {
		"source_size": CloudBlueprint.SOURCE_SIZE,
		"source_used_rect": CloudBlueprint.SOURCE_USED_RECT,
		"source_rgba_sha256": CloudBlueprint.SOURCE_RGBA_SHA256,
		"canvas_size": CANVAS_SIZE,
		"core_origin_x": CORE_ORIGIN_X,
		"screen_pixel_size": SCREEN_PIXEL_SIZE,
		"single_source_copy": true,
	}


func render_frame_for_testing(frame_index: int) -> Image:
	_ensure_runtime_buffers()
	return Image.create_from_data(
			CANVAS_SIZE.x, CANVAS_SIZE.y, false, Image.FORMAT_RGBA8,
			_build_frame_data(frame_index))


func render_authored_baseline_for_testing() -> Image:
	_ensure_runtime_buffers()
	return Image.create_from_data(
			CANVAS_SIZE.x, CANVAS_SIZE.y, false, Image.FORMAT_RGBA8,
			_base_data)


func baseline_contract_snapshot() -> Dictionary:
	_ensure_runtime_buffers()
	var left_padding_opaque := 0
	var right_padding_opaque := 0
	var removed_left_bottom := 0
	var removed_marked_horizon := 0
	var orange_protected_changes := 0
	var other_source_changes := 0
	var source_size: Vector2i = CloudBlueprint.SOURCE_SIZE
	for y: int in range(CANVAS_SIZE.y):
		for x: int in range(CORE_ORIGIN_X):
			if _base_data[(y * CANVAS_SIZE.x + x) * 4 + 3] != 0:
				left_padding_opaque += 1
		for x: int in range(CORE_ORIGIN_X + source_size.x, CANVAS_SIZE.x):
			if _base_data[(y * CANVAS_SIZE.x + x) * 4 + 3] != 0:
				right_padding_opaque += 1
	for source_y: int in range(source_size.y):
		for source_x: int in range(source_size.x):
			var source_byte: int = (source_y * source_size.x + source_x) * 4
			var canvas_byte: int = (
					source_y * CANVAS_SIZE.x + CORE_ORIGIN_X + source_x) * 4
			if not _pixel_differs(_source_data, _base_data,
					source_byte, canvas_byte):
				continue
			if ORANGE_PROTECTED_RECT.has_point(Vector2i(source_x, source_y)):
				orange_protected_changes += 1
			elif _is_marked_left_horizon_pixel(source_x, source_y) \
					and _source_data[source_byte + 3] != 0 \
					and _base_data[canvas_byte + 3] == 0:
				removed_marked_horizon += 1
			elif LEFT_BOTTOM_SPUR_RECT.has_point(Vector2i(source_x, source_y)) \
					and _source_data[source_byte + 3] != 0 \
					and _base_data[canvas_byte + 3] == 0:
				removed_left_bottom += 1
			else:
				other_source_changes += 1
	return {
		"left_padding_opaque_pixels": left_padding_opaque,
		"right_padding_opaque_pixels": right_padding_opaque,
		"removed_left_bottom_pixels": removed_left_bottom,
		"removed_marked_horizon_pixels": removed_marked_horizon,
		"other_source_pixel_changes": other_source_changes,
		"removed_source_rect": LEFT_BOTTOM_SPUR_RECT,
		"marked_horizon_annotation_bounds": MARKED_LEFT_HORIZON_ANNOTATION,
		"marked_horizon_cleanup_bounds": MARKED_LEFT_HORIZON_CLEANUP,
		"orange_protected_bounds": ORANGE_PROTECTED_RECT,
		"orange_protected_pixel_changes": orange_protected_changes,
	}


func coverage_snapshot(frame_index: int) -> Dictionary:
	var frame: Image = render_frame_for_testing(frame_index)
	var data: PackedByteArray = frame.get_data()
	var source_size: Vector2i = CloudBlueprint.SOURCE_SIZE
	var covered_columns := 0
	var left_padding_opaque := 0
	var right_padding_opaque := 0
	for x: int in range(CANVAS_SIZE.x):
		var covered := false
		for y: int in range(CANVAS_SIZE.y):
			if data[(y * CANVAS_SIZE.x + x) * 4 + 3] != 0:
				covered = true
				if x < CORE_ORIGIN_X:
					left_padding_opaque += 1
				elif x >= CORE_ORIGIN_X + source_size.x:
					right_padding_opaque += 1
		if covered:
			covered_columns += 1
	return {
		"columns": CANVAS_SIZE.x,
		"rows": CANVAS_SIZE.y,
		"bottom_covered_columns": covered_columns,
		"left_padding_opaque_pixels": left_padding_opaque,
		"right_padding_opaque_pixels": right_padding_opaque,
		"used_rect": frame.get_used_rect(),
	}


func count_changed_pixels(first_frame: int, second_frame: int) -> int:
	var first: PackedByteArray = render_frame_for_testing(first_frame).get_data()
	var second: PackedByteArray = render_frame_for_testing(second_frame).get_data()
	var changed := 0
	for pixel_index: int in range(CANVAS_SIZE.x * CANVAS_SIZE.y):
		var byte_index: int = pixel_index * 4
		if _pixel_differs(first, second, byte_index, byte_index):
			changed += 1
	return changed


func animation_metrics(first_frame: int, second_frame: int) -> Dictionary:
	_ensure_runtime_buffers()
	var first: PackedByteArray = _build_frame_data(first_frame)
	var second: PackedByteArray = _build_frame_data(second_frame)
	var impact_x: int = int(round(_impact_source_x()))
	var authored_palette: Dictionary = _authored_palette()
	var dark_changes := 0
	var mid_changes := 0
	var light_changes := 0
	var left_changes := 0
	var right_changes := 0
	var palette_outliers := 0
	for y: int in range(CANVAS_SIZE.y):
		for x: int in range(CORE_ORIGIN_X,
				CORE_ORIGIN_X + CloudBlueprint.SOURCE_SIZE.x):
			var byte_index: int = (y * CANVAS_SIZE.x + x) * 4
			if not _pixel_differs(first, second, byte_index, byte_index):
				continue
			if x < impact_x:
				left_changes += 1
			else:
				right_changes += 1
			var first_class: int = _palette_class(first, byte_index)
			var second_class: int = _palette_class(second, byte_index)
			if first_class == 0 or second_class == 0:
				dark_changes += 1
			if first_class == 1 or second_class == 1:
				mid_changes += 1
			if first_class == 2 or second_class == 2:
				light_changes += 1
			if second[byte_index + 3] != 0 \
					and not authored_palette.has(_rgb_key(second, byte_index)):
				palette_outliers += 1
	var contour: Dictionary = _contour_change_metrics(first, second)
	return {
		"palette_outlier_pixels": palette_outliers,
		"dark_region_changes": dark_changes,
		"mid_region_changes": mid_changes,
		"light_region_changes": light_changes,
		"left_body_changes": left_changes,
		"right_body_changes": right_changes,
		"top_contour_alpha_changes": contour["top_changes"],
		"maximum_top_displacement_px": contour["maximum_top_displacement"],
		"bottom_contour_alpha_changes": contour["bottom_changes"],
	}


func flow_contract_snapshot() -> Dictionary:
	return {
		"direction": "outward_from_impact",
		"vertical_phase_weight": 0,
		"maximum_horizontal_displacement_px": maximum_horizontal_displacement_px,
		"maximum_vertical_displacement_px": maximum_vertical_displacement_px,
		"bottom_lock_depth_px": bottom_lock_depth_px,
		"source_phase_step_per_frame":
				1.0 / TEMPORAL_SAMPLES_PER_SOURCE_PHASE,
		"cycle_duration_seconds": cycle_duration_seconds(),
		"generated_palette_colors": 0,
		"source_copy_count": 1,
	}


func _configure_gpu_material() -> void:
	var assigned_material := material as ShaderMaterial
	if assigned_material == null:
		push_error("Scene9 cloud requires its local GPU cloud material")
		return
	_cloud_material = assigned_material.duplicate() as ShaderMaterial
	_cloud_material.resource_local_to_scene = true
	material = _cloud_material
	_cloud_material.set_shader_parameter(&"metadata_texture", _metadata_texture)
	_cloud_material.set_shader_parameter(&"cloud_texture", texture)
	_cloud_material.set_shader_parameter(&"impact_source_x_px", _impact_source_x())
	_cloud_material.set_shader_parameter(
			&"maximum_horizontal_displacement_px",
			float(maximum_horizontal_displacement_px))
	_cloud_material.set_shader_parameter(
			&"maximum_vertical_displacement_px",
			float(maximum_vertical_displacement_px))
	_cloud_material.set_shader_parameter(
			&"bottom_lock_depth_px", float(bottom_lock_depth_px))
	_cloud_material.set_shader_parameter(
			&"motion_blend_depth_px", float(motion_blend_depth_px))


func _apply_shader_state(frame_index: int) -> void:
	_visible_frame = posmod(frame_index, loop_frame_count)
	if _cloud_material == null:
		return
	_cloud_material.set_shader_parameter(
			&"source_phase",
			float(_visible_frame) / TEMPORAL_SAMPLES_PER_SOURCE_PHASE)
	for slot: int in RIPPLE_POOL_SIZE:
		var phase := clampf(
				_ripple_ages[slot] / RIPPLE_LIFETIME_SECONDS, 0.0, 1.0)
		_cloud_material.set_shader_parameter(
				StringName("ripple_wave_%d" % slot),
				Vector4(
						_ripple_centers[slot].x,
						_ripple_centers[slot].y,
						phase,
						1.0 if _ripple_active_slots[slot] else 0.0))


func _advance_ripples(delta: float) -> void:
	for slot: int in RIPPLE_POOL_SIZE:
		if not _ripple_active_slots[slot]:
			continue
		_ripple_ages[slot] = minf(
				_ripple_ages[slot] + delta, RIPPLE_LIFETIME_SECONDS)
		if _ripple_ages[slot] >= RIPPLE_LIFETIME_SECONDS:
			_ripple_active_slots[slot] = false


func _combined_ripple_tick() -> int:
	var tick := -1
	for slot: int in RIPPLE_POOL_SIZE:
		if _ripple_active_slots[slot]:
			tick = maxi(tick, int(floor(_ripple_ages[slot] * 60.0))
					+ _ripple_serials[slot] * 97)
	return tick


func _select_ripple_slot() -> int:
	for slot: int in RIPPLE_POOL_SIZE:
		if not _ripple_active_slots[slot]:
			return slot
	var oldest_slot := 0
	for slot: int in range(1, RIPPLE_POOL_SIZE):
		if _ripple_serials[slot] < _ripple_serials[oldest_slot]:
			oldest_slot = slot
	return oldest_slot


func _ensure_runtime_buffers() -> void:
	if _base_data.is_empty():
		_build_runtime_buffers()


func _build_runtime_buffers() -> void:
	if not _base_data.is_empty():
		return
	if not _shared_base_data.is_empty():
		_source_data = _shared_source_data
		_base_data = _shared_base_data
		_top_edge_y = _shared_top_edge_y
		_bottom_edge_y = _shared_bottom_edge_y
		_interior_depth = _shared_interior_depth
		_metadata_texture = _shared_metadata_texture
		texture = _shared_base_texture
		return
	_source_data = CloudBlueprint.source_rgba()
	var source_size: Vector2i = CloudBlueprint.SOURCE_SIZE
	_base_data.resize(CANVAS_SIZE.x * CANVAS_SIZE.y * 4)
	_base_data.fill(0)
	for source_y: int in range(source_size.y):
		for source_x: int in range(source_size.x):
			if LEFT_BOTTOM_SPUR_RECT.has_point(Vector2i(source_x, source_y)) \
					or _is_marked_left_horizon_pixel(source_x, source_y):
				continue
			var source_byte: int = (source_y * source_size.x + source_x) * 4
			var canvas_byte: int = (
					source_y * CANVAS_SIZE.x + CORE_ORIGIN_X + source_x) * 4
			_copy_pixel(_source_data, _base_data, source_byte, canvas_byte)
	_build_edge_profiles()
	_build_interior_depth()
	var base_image := Image.create_from_data(
			CANVAS_SIZE.x, CANVAS_SIZE.y, false,
			Image.FORMAT_RGBA8, _base_data)
	_shared_source_data = _source_data
	_shared_base_data = _base_data
	_shared_top_edge_y = _top_edge_y
	_shared_bottom_edge_y = _bottom_edge_y
	_shared_interior_depth = _interior_depth
	_shared_base_texture = ImageTexture.create_from_image(base_image)
	_shared_metadata_texture = _build_metadata_texture()
	_metadata_texture = _shared_metadata_texture
	texture = _shared_base_texture


func _build_metadata_texture() -> ImageTexture:
	var metadata := PackedByteArray()
	metadata.resize(CANVAS_SIZE.x * CANVAS_SIZE.y * 4)
	metadata.fill(0)
	for y: int in CANVAS_SIZE.y:
		for x: int in CANVAS_SIZE.x:
			var byte_index := (y * CANVAS_SIZE.x + x) * 4
			metadata[byte_index] = clampi(
					roundi(float(_interior_depth[y * CANVAS_SIZE.x + x])
							/ 3.0 * 255.0), 0, 255)
			var bottom_y := _bottom_edge_y[x]
			var top_y := _top_edge_y[x]
			metadata[byte_index + 1] = clampi(bottom_y + 1, 0, 255)
			metadata[byte_index + 2] = clampi(top_y + 1, 0, 255)
			metadata[byte_index + 3] = 255 if bottom_y >= 0 else 0
	var image := Image.create_from_data(
			CANVAS_SIZE.x, CANVAS_SIZE.y, false,
			Image.FORMAT_RGBA8, metadata)
	return ImageTexture.create_from_image(image)


func _build_edge_profiles() -> void:
	_top_edge_y.resize(CANVAS_SIZE.x)
	_bottom_edge_y.resize(CANVAS_SIZE.x)
	_top_edge_y.fill(-1)
	_bottom_edge_y.fill(-1)
	for x: int in range(CANVAS_SIZE.x):
		for y: int in range(CANVAS_SIZE.y):
			if _base_data[(y * CANVAS_SIZE.x + x) * 4 + 3] == 0:
				continue
			if _top_edge_y[x] < 0:
				_top_edge_y[x] = y
			_bottom_edge_y[x] = y


func _build_interior_depth() -> void:
	_interior_depth.resize(CANVAS_SIZE.x * CANVAS_SIZE.y)
	_interior_depth.fill(0)
	for y: int in range(3, CANVAS_SIZE.y - 3):
		for x: int in range(CORE_ORIGIN_X + 3,
				CORE_ORIGIN_X + CloudBlueprint.SOURCE_SIZE.x - 3):
			var pixel_index: int = y * CANVAS_SIZE.x + x
			if _base_data[pixel_index * 4 + 3] == 0:
				continue
			var depth := 0
			for radius: int in range(1, 4):
				var surrounded := true
				for offset_y: int in range(-radius, radius + 1):
					for offset_x: int in range(-radius, radius + 1):
						var neighbor: int = (
								(y + offset_y) * CANVAS_SIZE.x + x + offset_x)
						if _base_data[neighbor * 4 + 3] == 0:
							surrounded = false
							break
					if not surrounded:
						break
				if not surrounded:
					break
				depth = radius
			_interior_depth[pixel_index] = depth


func _apply_ripple_to_data(
		input: PackedByteArray, phase: float, center: Vector2) -> PackedByteArray:
	var output := input.duplicate()
	var envelope := _interaction_envelope(phase, 0.24)
	if envelope <= 0.0001:
		return output
	var leading_radius := lerpf(
			2.0, RIPPLE_MAX_RADIUS_PX, 1.0 - pow(1.0 - phase, 2.0))
	var rings: PackedFloat32Array = [
		leading_radius,
		leading_radius - 7.0,
		leading_radius - 14.0,
	]
	for y: int in range(CANVAS_SIZE.y):
		for x: int in range(CORE_ORIGIN_X,
				CORE_ORIGIN_X + CloudBlueprint.SOURCE_SIZE.x):
			var pixel_index := y * CANVAS_SIZE.x + x
			var destination_byte := pixel_index * 4
			if input[destination_byte + 3] == 0 \
					or _interior_depth[pixel_index] == 0:
				continue
			var bottom_y := _bottom_edge_y[x]
			if bottom_y < 0 or bottom_y - y < bottom_lock_depth_px:
				continue
			var delta := Vector2(float(x), float(y)) - center
			var distance := delta.length()
			var ring_weight := 0.0
			for ring_index: int in rings.size():
				var radius := rings[ring_index]
				if radius <= 0.0:
					continue
				var band := 1.0 - clampf(absf(distance - radius) / 2.6, 0.0, 1.0)
				ring_weight = maxf(
						ring_weight,
						band * (1.0 - float(ring_index) * 0.22))
			var displacement := int(round(
					float(RIPPLE_MAX_DISPLACEMENT_PX) * ring_weight * envelope))
			if displacement <= 0 or distance <= 0.001:
				continue
			var direction := delta / distance
			var source := Vector2i(
					x - int(round(direction.x * float(displacement))),
					y - int(round(direction.y * float(displacement))))
			if source.x < CORE_ORIGIN_X \
					or source.x >= CORE_ORIGIN_X + CloudBlueprint.SOURCE_SIZE.x \
					or source.y < 0 or source.y >= CANVAS_SIZE.y:
				continue
			var source_byte := (source.y * CANVAS_SIZE.x + source.x) * 4
			if input[source_byte + 3] == 0:
				continue
			_copy_pixel(input, output, source_byte, destination_byte)
	return output


func _interaction_envelope(phase: float, attack_fraction: float) -> float:
	var normalized := clampf(phase, 0.0, 1.0)
	if normalized <= attack_fraction:
		return _smootherstep(normalized / maxf(attack_fraction, 0.001))
	return 1.0 - _smootherstep(
			(normalized - attack_fraction) / maxf(1.0 - attack_fraction, 0.001))


func _smootherstep(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


func _canvas_position_to_source_pixel(canvas_position: Vector2) -> Vector2i:
	var local_position := get_global_transform_with_canvas().affine_inverse() \
			* canvas_position
	if not Rect2(Vector2.ZERO, size).has_point(local_position):
		return Vector2i(-1, -1)
	var normalized := local_position / size
	return Vector2i(
			clampi(int(floor(normalized.x * float(CANVAS_SIZE.x))),
					0, CANVAS_SIZE.x - 1),
			clampi(int(floor(normalized.y * float(CANVAS_SIZE.y))),
					0, CANVAS_SIZE.y - 1))


func _opaque_source_pixel_at_canvas_position(
		canvas_position: Vector2) -> Vector2i:
	_ensure_runtime_buffers()
	var destination_pixel := _canvas_position_to_source_pixel(canvas_position)
	if destination_pixel.x < 0:
		return Vector2i(-1, -1)
	var source_pixel := _animated_source_pixel_for_frame(
			destination_pixel, maxi(_visible_frame, 0))
	if source_pixel.x < 0:
		return Vector2i(-1, -1)
	var byte_index := (source_pixel.y * CANVAS_SIZE.x + source_pixel.x) * 4
	if _base_data[byte_index + 3] == 0:
		return Vector2i(-1, -1)
	return source_pixel


func _animated_source_pixel_for_frame(
		destination_pixel: Vector2i, frame_index: int) -> Vector2i:
	if destination_pixel.x < 0 or destination_pixel.x >= CANVAS_SIZE.x \
			or destination_pixel.y < 0 or destination_pixel.y >= CANVAS_SIZE.y:
		return Vector2i(-1, -1)
	var bottom_y := _bottom_edge_y[destination_pixel.x]
	if bottom_y < 0:
		return Vector2i(-1, -1)
	var distance_from_bottom := bottom_y - destination_pixel.y
	if distance_from_bottom < bottom_lock_depth_px:
		return destination_pixel
	var motion_weight := clampf(
			float(distance_from_bottom - bottom_lock_depth_px + 1)
			/ float(motion_blend_depth_px), 0.0, 1.0)
	var interior_weight := float(_interior_depth[
			destination_pixel.y * CANVAS_SIZE.x + destination_pixel.x]) / 3.0
	var source_time_phase := float(posmod(frame_index, loop_frame_count)) \
			/ TEMPORAL_SAMPLES_PER_SOURCE_PHASE
	var radial_distance := absi(
			destination_pixel.x - roundi(_impact_source_x()))
	var phase := fposmod(
			float(radial_distance) - source_time_phase,
			SOURCE_PHASE_PERIOD_PX)
	var outward_wave := 0.5 + 0.5 * sin(
			TAU * phase / SOURCE_PHASE_PERIOD_PX)
	var vertical_wave := sin(
			TAU * (phase + SOURCE_PHASE_PERIOD_PX / 4.0)
			/ SOURCE_PHASE_PERIOD_PX)
	var horizontal_shift := roundi(
			outward_wave * float(maximum_horizontal_displacement_px)
			* motion_weight * interior_weight)
	var vertical_shift := roundi(
			vertical_wave * float(maximum_vertical_displacement_px)
			* motion_weight)
	var direction := -1 if destination_pixel.x < roundi(
			_impact_source_x()) else 1
	var source_pixel := destination_pixel - Vector2i(
			direction * horizontal_shift, vertical_shift)
	if source_pixel.x < CORE_ORIGIN_X \
			or source_pixel.x >= CORE_ORIGIN_X + CloudBlueprint.SOURCE_SIZE.x \
			or source_pixel.y < 0 or source_pixel.y >= CANVAS_SIZE.y:
		return Vector2i(-1, -1)
	return source_pixel


func _zone_for_source_pixel(source_pixel: Vector2i) -> int:
	var authored_x := source_pixel.x - CORE_ORIGIN_X
	var normalized := clampf(
			float(authored_x) / float(CloudBlueprint.SOURCE_SIZE.x), 0.0, 0.999)
	return clampi(int(floor(normalized * 3.0)), 0, 2)


func _build_frame_data(frame_index: int) -> PackedByteArray:
	var frame: int = posmod(frame_index, loop_frame_count)
	var source_time_phase: float = (
			float(frame) / TEMPORAL_SAMPLES_PER_SOURCE_PHASE)
	var result := PackedByteArray()
	result.resize(_base_data.size())
	result.fill(0)
	var impact_x: int = int(round(_impact_source_x()))
	var source_size: Vector2i = CloudBlueprint.SOURCE_SIZE
	var outward_wave_by_x := PackedFloat64Array()
	var vertical_wave_by_x := PackedFloat64Array()
	outward_wave_by_x.resize(CANVAS_SIZE.x)
	vertical_wave_by_x.resize(CANVAS_SIZE.x)
	for x: int in range(CORE_ORIGIN_X, CORE_ORIGIN_X + source_size.x):
		var radial_distance: int = absi(x - impact_x)
		var phase: float = fposmod(
				float(radial_distance) - source_time_phase,
				SOURCE_PHASE_PERIOD_PX)
		outward_wave_by_x[x] = 0.5 + 0.5 * sin(
				TAU * phase / SOURCE_PHASE_PERIOD_PX)
		vertical_wave_by_x[x] = sin(
				TAU * (phase + SOURCE_PHASE_PERIOD_PX / 4.0)
				/ SOURCE_PHASE_PERIOD_PX)
	for y: int in range(CANVAS_SIZE.y):
		for x: int in range(CORE_ORIGIN_X, CORE_ORIGIN_X + source_size.x):
			var destination_byte: int = (y * CANVAS_SIZE.x + x) * 4
			var bottom_y: int = _bottom_edge_y[x]
			if bottom_y < 0:
				continue
			var distance_from_bottom: int = bottom_y - y
			if distance_from_bottom < bottom_lock_depth_px:
				_copy_pixel(_base_data, result,
						destination_byte, destination_byte)
				continue
			var motion_weight: float = clampf(
					float(distance_from_bottom - bottom_lock_depth_px + 1)
					/ float(motion_blend_depth_px), 0.0, 1.0)
			var interior_weight: float = float(
					_interior_depth[y * CANVAS_SIZE.x + x]) / 3.0
			var horizontal_shift: int = int(round(
					outward_wave_by_x[x]
					* float(maximum_horizontal_displacement_px)
					* motion_weight * interior_weight))
			var vertical_shift: int = int(round(
					vertical_wave_by_x[x]
					* float(maximum_vertical_displacement_px)
					* motion_weight))
			var direction: int = -1 if x < impact_x else 1
			var source_x: int = x - direction * horizontal_shift
			var source_y: int = y - vertical_shift
			if source_x < CORE_ORIGIN_X \
					or source_x >= CORE_ORIGIN_X + source_size.x \
					or source_y < 0 or source_y >= CANVAS_SIZE.y:
				continue
			var source_byte: int = (source_y * CANVAS_SIZE.x + source_x) * 4
			_copy_pixel(_base_data, result, source_byte, destination_byte)
	return result


func _is_marked_left_horizon_pixel(source_x: int, source_y: int) -> bool:
	if not MARKED_LEFT_HORIZON_CLEANUP.has_point(Vector2i(source_x, source_y)):
		return false
	var cutoff_y := 113
	if source_x >= 80:
		cutoff_y = 117
	elif source_x >= 77:
		cutoff_y = 116
	elif source_x >= 74:
		cutoff_y = 115
	elif source_x >= 68:
		cutoff_y = 114
	return source_y >= cutoff_y


func _contour_change_metrics(
		first: PackedByteArray, second: PackedByteArray) -> Dictionary:
	var top_changes := 0
	var bottom_changes := 0
	var maximum_top_displacement := 0
	var source_size: Vector2i = CloudBlueprint.SOURCE_SIZE
	for x: int in range(CORE_ORIGIN_X, CORE_ORIGIN_X + source_size.x):
		var first_top: int = _column_top(first, x)
		var second_top: int = _column_top(second, x)
		var first_bottom: int = _column_bottom(first, x)
		var second_bottom: int = _column_bottom(second, x)
		if first_top != second_top:
			top_changes += 1
			if first_top >= 0 and second_top >= 0:
				maximum_top_displacement = maxi(maximum_top_displacement,
						absi(first_top - second_top))
		if first_bottom != second_bottom:
			bottom_changes += 1
	return {
		"top_changes": top_changes,
		"maximum_top_displacement": maximum_top_displacement,
		"bottom_changes": bottom_changes,
	}


func _column_top(data: PackedByteArray, x: int) -> int:
	for y: int in range(CANVAS_SIZE.y):
		if data[(y * CANVAS_SIZE.x + x) * 4 + 3] != 0:
			return y
	return -1


func _column_bottom(data: PackedByteArray, x: int) -> int:
	for y: int in range(CANVAS_SIZE.y - 1, -1, -1):
		if data[(y * CANVAS_SIZE.x + x) * 4 + 3] != 0:
			return y
	return -1


func _authored_palette() -> Dictionary:
	var palette: Dictionary = {}
	for pixel_index: int in range(_base_data.size() / 4):
		var byte_index: int = pixel_index * 4
		if _base_data[byte_index + 3] != 0:
			palette[_rgb_key(_base_data, byte_index)] = true
	return palette


func _palette_class(data: PackedByteArray, byte_index: int) -> int:
	if data[byte_index + 3] == 0:
		return -1
	var luma: float = _byte_luma(data, byte_index)
	if luma < DARK_LUMA_MAX:
		return 0
	if luma >= LIGHT_LUMA_MIN:
		return 2
	return 1


func _byte_luma(data: PackedByteArray, byte_index: int) -> float:
	return float(data[byte_index]) * 0.2126 \
			+ float(data[byte_index + 1]) * 0.7152 \
			+ float(data[byte_index + 2]) * 0.0722


func _rgb_key(data: PackedByteArray, byte_index: int) -> int:
	return int(data[byte_index]) << 16 \
			| int(data[byte_index + 1]) << 8 \
			| int(data[byte_index + 2])


func _copy_pixel(
		source: PackedByteArray, destination: PackedByteArray,
		source_byte: int, destination_byte: int) -> void:
	for channel: int in range(4):
		destination[destination_byte + channel] = source[source_byte + channel]


func _pixel_differs(
		first: PackedByteArray, second: PackedByteArray,
		first_byte: int, second_byte: int) -> bool:
	for channel: int in range(4):
		if first[first_byte + channel] != second[second_byte + channel]:
			return true
	return false


func _impact_source_x() -> float:
	var origin := get_node_or_null(impact_origin_path) as Node2D
	if origin == null or not is_inside_tree():
		return CORE_ORIGIN_X + CloudBlueprint.SOURCE_SIZE.x * 0.67
	var local_origin: Vector2 = get_global_transform().affine_inverse() \
			* origin.global_position
	return clampf(local_origin.x / SCREEN_PIXEL_SIZE,
			float(CORE_ORIGIN_X),
			float(CORE_ORIGIN_X + CloudBlueprint.SOURCE_SIZE.x - 1))
