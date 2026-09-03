@tool
extends Control

## Code-only reconstruction of the authored Scene9 cloud macro silhouette.
## The 68-column profiles were measured offline from scene9_cloud_layer alpha;
## the runtime scene never loads or samples that texture. Only palette bands and
## Scene2 WaterfallCloudLower's four-tier lobes, joined base, exposed top light,
## counter-phased flow and restrained breath are clipped by that fixed outline.

const PROFILE_COLUMNS := 68
const PROFILE_ROWS := 24
const SILHOUETTE_TOP := [
	6, 5, 4, 5, 6, 8, 9, 9, 8, 9, 9, 11, 13, 12, 12, 12, 14,
	14, 15, 15, 14, 14, 15, 15, 15, 16, 16, 17, 17, 16, 16, 16, 15,
	15, 15, 15, 15, 15, 16, 17, 17, 17, 17, 16, 16, 16, 16, 17, 15,
	14, 14, 14, 13, 11, 10, 10, 10, 9, 8, 8, 5, 4, 3, 3, 3, 4, 5, 6,
]
const SILHOUETTE_BOTTOM := [
	19, 20, 20, 20, 20, 20, 20, 20, 20, 20, 21, 20, 20, 20, 20, 20,
	20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 21, 21, 21, 21, 21,
	20, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21,
	21, 21, 21, 20, 20, 20, 20, 20, 20, 20, 21, 21, 21, 21, 20, 20,
	20, 20, 17, 16,
]

@export var impact_origin_path: NodePath
@export_range(6, 16, 1) var cell_size_px: int = 8
@export_range(3.0, 10.0, 0.5) var animation_fps: float = 6.0
@export_range(20.0, 100.0, 1.0) var outward_speed_px: float = 42.0
@export_range(120.0, 360.0, 8.0) var wave_period_px: float = 240.0
@export_range(128.0, 320.0, 8.0) var lobe_width_px: float = 224.0
@export_range(2, 4, 1) var row_count: int = 4
@export_range(0.0, 0.15, 0.01) var breath_amount: float = 0.07
@export var shadow_color: Color = Color8(144, 200, 224, 126)
@export var body_color: Color = Color8(160, 208, 240, 150)
@export var light_color: Color = Color8(224, 240, 240, 164)

var _motion_time: float = 0.0
var _draw_frame: int = -1


func _ready() -> void:
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_motion_time = fposmod(
			_motion_time + maxf(delta, 0.0),
			wave_period_px / maxf(outward_speed_px, 0.001))
	var next_frame := int(floor(_motion_time * animation_fps))
	if next_frame != _draw_frame:
		_draw_frame = next_frame
		queue_redraw()


func impact_center_local() -> Vector2:
	var origin_node := get_node_or_null(impact_origin_path) as Node2D
	if origin_node == null:
		return Vector2(size.x * 0.67, size.y * 0.72)
	return get_global_transform().affine_inverse() * origin_node.global_position


func silhouette_signature() -> Dictionary:
	return {
		"columns": PROFILE_COLUMNS,
		"rows": PROFILE_ROWS,
		"left_top": SILHOUETTE_TOP[0],
		"center_top": SILHOUETTE_TOP[PROFILE_COLUMNS >> 1],
		"right_top": SILHOUETTE_TOP[PROFILE_COLUMNS - 1],
		"top_sum": _sum_profile(SILHOUETTE_TOP),
		"bottom_sum": _sum_profile(SILHOUETTE_BOTTOM),
	}


func spread_snapshot(time_sec: float) -> Dictionary:
	var origin := impact_center_local()
	var travel := fposmod(time_sec * outward_speed_px, wave_period_px)
	return {
		"origin": origin,
		"left_front": origin.x - travel,
		"right_front": origin.x + travel,
		"front_distance": travel,
	}


func count_filled_cells_at(time_sec: float) -> int:
	var columns := ceili(size.x / float(cell_size_px))
	var rows := ceili(size.y / float(cell_size_px))
	var filled := 0
	for row: int in range(rows):
		for column: int in range(columns):
			if _is_filled_cell(column, row, columns, rows, time_sec):
				filled += 1
	return filled


func count_changed_palette_cells(first_time: float, second_time: float) -> int:
	var origin := impact_center_local()
	var columns := ceili(size.x / float(cell_size_px))
	var rows := ceili(size.y / float(cell_size_px))
	var changed := 0
	for row: int in range(rows):
		for column: int in range(columns):
			if not _is_filled_cell(column, row, columns, rows, first_time):
				continue
			var point_x := (column + 0.5) * cell_size_px
			if _palette_index(point_x, row, origin.x, first_time) \
					!= _palette_index(point_x, row, origin.x, second_time):
				changed += 1
	return changed


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var origin := impact_center_local()
	var columns := ceili(size.x / float(cell_size_px))
	var rows := ceili(size.y / float(cell_size_px))
	for row: int in range(rows):
		for column: int in range(columns):
			if not _is_filled_cell(column, row, columns, rows, _motion_time):
				continue
			var point_x := (column + 0.5) * cell_size_px
			var palette_index := _palette_index(
					point_x, row, origin.x, _motion_time)
			var color := body_color
			var is_exposed_top := not _is_filled_cell(
					column, row - 1, columns, rows, _motion_time)
			if is_exposed_top:
				color = light_color
			elif palette_index == 0:
				color = shadow_color
			elif palette_index == 2:
				color = light_color
			var lobe_id := floori(
					(absf(point_x - origin.x)
							- _motion_time * outward_speed_px) / lobe_width_px)
			var breath := 1.0 - breath_amount * (
					0.5 + 0.5 * sin(_motion_time * 0.13 + lobe_id * 2.9))
			color.a *= breath
			draw_rect(Rect2(
					Vector2(column * cell_size_px, row * cell_size_px),
					Vector2(cell_size_px, cell_size_px)), color)


func _is_filled_cell(
		column: int, row: int, columns: int, rows: int, time_sec: float) -> bool:
	var profile_column := clampi(
			floori(float(column) / maxf(columns, 1.0) * PROFILE_COLUMNS),
			0, PROFILE_COLUMNS - 1)
	var profile_row := float(row) / maxf(rows, 1.0) * PROFILE_ROWS
	var top := float(SILHOUETTE_TOP[profile_column])
	var bottom := float(SILHOUETTE_BOTTOM[profile_column] + 1)
	return profile_row >= top and profile_row < bottom


func _palette_index(
		point_x: float, row: int, origin_x: float, time_sec: float) -> int:
	var radial_distance := absf(point_x - origin_x)
	var primary_coordinate := radial_distance - time_sec * outward_speed_px
	var secondary_coordinate := (
			radial_distance - time_sec * outward_speed_px * 0.72
					+ lobe_width_px * 0.38)
	var primary_u := fposmod(primary_coordinate, lobe_width_px) / lobe_width_px
	var secondary_u := fposmod(
			secondary_coordinate, lobe_width_px) / lobe_width_px
	var primary_x := primary_u * 2.0 - 1.0
	var secondary_x := secondary_u * 2.0 - 1.0
	var primary_arch := sqrt(maxf(1.0 - primary_x * primary_x, 0.0))
	var secondary_arch := sqrt(maxf(1.0 - secondary_x * secondary_x, 0.0))
	primary_arch = floorf(primary_arch * row_count + 0.5) / row_count
	secondary_arch = floorf(secondary_arch * row_count + 0.5) / row_count
	var row_phase := float(posmod(row, row_count * 3)) / float(row_count * 3)
	# Scene2's first cloud pass supplies the bright stepped lobe; its slower,
	# offset second pass fills joins and leaves a broad shadow tier underneath.
	if row_phase < primary_arch * 0.32:
		return 2
	if row_phase > 0.72 or row_phase > secondary_arch * 0.58 + 0.24:
		return 0
	return 1


func _sum_profile(profile: Array) -> int:
	var total := 0
	for value: int in profile:
		total += value
	return total
