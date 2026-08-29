class_name Scene8LakeTopology
extends Node

signal topology_rebuilt(texture: Texture2D)

## Builds the Scene8 lake occupancy data once from the authored snowfield pair
## alpha. R = water occupancy, G = normalized water-side shore distance,
## B = per-column perspective depth, A = measured FarGlacier water-contact
## proximity. The same texture is bound to the water base, aurora reflection,
## and platform-contact materials.

@export var grid_size: Vector2i = Vector2i(320, 180)
@export var design_size: Vector2 = Vector2(1920.0, 1080.0)
@export_range(0.0, 1.0, 0.001) var mountain_alpha_threshold: float = 0.03
@export_range(0, 4, 1) var shore_overlap_cells: int = 2
@export_range(1, 64, 1) var shore_distance_cells: int = 24
@export_range(0.35, 0.75, 0.005) var fallback_horizon_y: float = 0.52
@export var far_mountain_path: NodePath = ^"../FarSnowfield"
@export var far_mountain_secondary_path: NodePath = ^"../FarSnowfield2"
@export var glacier_path: NodePath = ^"../FarGlacier"
@export_range(1, 8, 1) var glacier_contact_cells: int = 4
@export var lake_path: NodePath = ^"../MirrorLake"
@export var reflection_path: NodePath = ^"../AuroraReflection"
@export var contact_path: NodePath = ^"../PlatformWaterContact"

var _mountain: TextureRect
var _base_mountain_origin: Vector2
var _base_mountain_draw_size: Vector2
var _target_materials: Array[ShaderMaterial] = []
var _topology_image: Image
var _topology_texture: ImageTexture
var _last_current_origin_uv: Vector2 = Vector2(INF, INF)
var _last_current_size_uv: Vector2 = Vector2(INF, INF)


func _ready() -> void:
	# BattleStage updates parallax at the default priority. Mapping uniforms run
	# afterwards so the topology follows the mountain in the same rendered frame.
	process_priority = 100
	set_process(false)
	if not rebuild():
		call_deferred(&"rebuild")


func _process(_delta: float) -> void:
	if _topology_texture != null:
		sync_shader_mapping()


func rebuild() -> bool:
	if grid_size.x <= 0 or grid_size.y <= 0:
		push_warning("Scene8LakeTopology: grid_size must be positive")
		return false

	var parent_node: Node = get_parent()
	if not parent_node is Control:
		push_warning("Scene8LakeTopology: parent must be the Scene8 Control")
		return false
	if design_size.x <= 0.0 or design_size.y <= 0.0:
		push_warning("Scene8LakeTopology: design_size must be positive")
		return false

	var mountain_node: Node = get_node_or_null(far_mountain_path)
	if not mountain_node is TextureRect:
		push_warning("Scene8LakeTopology: primary FarSnowfield path is invalid")
		return false
	var candidate_mountain: TextureRect = mountain_node as TextureRect
	if candidate_mountain.texture == null:
		push_warning("Scene8LakeTopology: FarSnowfield has no texture")
		return false
	var mountain_image: Image = candidate_mountain.texture.get_image()
	if mountain_image == null or mountain_image.is_empty():
		push_warning("Scene8LakeTopology: FarSnowfield image is unavailable")
		return false
	var candidate_mountains: Array[TextureRect] = [candidate_mountain]
	var secondary_node: Node = get_node_or_null(far_mountain_secondary_path)
	if secondary_node is TextureRect:
		var secondary := secondary_node as TextureRect
		if secondary.texture != null:
			var secondary_image := secondary.texture.get_image()
			if secondary_image != null and not secondary_image.is_empty():
				candidate_mountains.append(secondary)
	var candidate_glacier: TextureRect
	var glacier_node: Node = get_node_or_null(glacier_path)
	if glacier_node is TextureRect:
		var glacier := glacier_node as TextureRect
		if glacier.texture != null:
			var glacier_image := glacier.texture.get_image()
			if glacier_image != null and not glacier_image.is_empty():
				candidate_glacier = glacier

	var lake_material: ShaderMaterial = _resolve_shader_material(lake_path)
	var reflection_material: ShaderMaterial = _resolve_shader_material(
			reflection_path)
	var contact_material: ShaderMaterial = _resolve_shader_material(contact_path)
	if (lake_material == null or reflection_material == null
			or contact_material == null):
		push_warning("Scene8LakeTopology: lake materials are unavailable")
		return false
	var candidate_materials: Array[ShaderMaterial] = [
		lake_material,
		reflection_material,
		contact_material,
	]

	var base_mountain_origin: Vector2 = candidate_mountain.position
	var base_mountain_draw_size: Vector2 = Vector2(
			candidate_mountain.size.x * candidate_mountain.scale.x,
			candidate_mountain.size.y * candidate_mountain.scale.y)
	if (base_mountain_draw_size.x <= 0.0
			or base_mountain_draw_size.y <= 0.0):
		push_warning("Scene8LakeTopology: FarSnowfield scale must be positive")
		return false

	var candidate_image: Image = _build_topology_image(
			candidate_mountains, candidate_glacier, design_size)
	var candidate_texture: ImageTexture = ImageTexture.create_from_image(
			candidate_image)
	var current_mapping: PackedVector2Array = _calculate_current_mapping(
			candidate_mountain,
			base_mountain_origin,
			base_mountain_draw_size)
	if current_mapping.size() != 2:
		return false
	var base_origin_uv := Vector2.ZERO
	var base_size_uv := Vector2.ONE
	for material: ShaderMaterial in candidate_materials:
		material.set_shader_parameter(&"lake_topology", candidate_texture)
		material.set_shader_parameter(&"topology_base_origin_uv", base_origin_uv)
		material.set_shader_parameter(&"topology_base_size_uv", base_size_uv)
		material.set_shader_parameter(
				&"topology_current_origin_uv", current_mapping[0])
		material.set_shader_parameter(
				&"topology_current_size_uv", current_mapping[1])
		material.set_shader_parameter(
				&"shore_distance_cells", float(shore_distance_cells))
		# Enable last so a failed rebuild never exposes a half-bound topology.
		material.set_shader_parameter(&"use_lake_topology", true)

	_mountain = candidate_mountain
	_base_mountain_origin = base_mountain_origin
	_base_mountain_draw_size = base_mountain_draw_size
	_target_materials = candidate_materials
	_topology_image = candidate_image
	_topology_texture = candidate_texture
	_last_current_origin_uv = current_mapping[0]
	_last_current_size_uv = current_mapping[1]
	set_process(true)
	topology_rebuilt.emit(_topology_texture)
	return true


func sync_shader_mapping() -> bool:
	if (_mountain == null or _target_materials.is_empty()
			or not is_inside_tree()):
		return false
	var current_mapping: PackedVector2Array = _calculate_current_mapping(
			_mountain,
			_base_mountain_origin,
			_base_mountain_draw_size)
	if current_mapping.size() != 2:
		return false
	var current_origin_uv: Vector2 = current_mapping[0]
	var current_size_uv: Vector2 = current_mapping[1]
	if (current_origin_uv.is_equal_approx(_last_current_origin_uv)
			and current_size_uv.is_equal_approx(_last_current_size_uv)):
		return true
	for material: ShaderMaterial in _target_materials:
		material.set_shader_parameter(
				&"topology_current_origin_uv", current_origin_uv)
		material.set_shader_parameter(
				&"topology_current_size_uv", current_size_uv)
	_last_current_origin_uv = current_origin_uv
	_last_current_size_uv = current_size_uv
	return true


func get_topology_image() -> Image:
	return _topology_image


func get_topology_texture() -> Texture2D:
	return _topology_texture


func sample_at_viewport_position(viewport_position: Vector2) -> Color:
	if _topology_image == null or _topology_image.is_empty():
		if not rebuild():
			return Color(0.0, 0.0, 0.0, 0.0)
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Color(0.0, 0.0, 0.0, 0.0)
	var screen_uv := viewport_position / viewport_size
	var current_size := Vector2(
			maxf(absf(_last_current_size_uv.x), 0.000001),
			maxf(absf(_last_current_size_uv.y), 0.000001))
	var topology_uv := (screen_uv - _last_current_origin_uv) / current_size
	if (topology_uv.x < 0.0 or topology_uv.y < 0.0
			or topology_uv.x >= 1.0 or topology_uv.y >= 1.0):
		return Color(0.0, 0.0, 0.0, 0.0)
	var pixel := Vector2i(
			clampi(floori(topology_uv.x * float(_topology_image.get_width())),
					0, _topology_image.get_width() - 1),
			clampi(floori(topology_uv.y * float(_topology_image.get_height())),
					0, _topology_image.get_height() - 1))
	return _topology_image.get_pixelv(pixel)


func _resolve_shader_material(node_path: NodePath) -> ShaderMaterial:
	var target_node: Node = get_node_or_null(node_path)
	if not target_node is CanvasItem:
		return null
	var target: CanvasItem = target_node as CanvasItem
	if not target.material is ShaderMaterial:
		return null
	return target.material as ShaderMaterial


func _calculate_current_mapping(
		mountain: TextureRect,
		base_origin: Vector2,
		base_draw_size: Vector2) -> PackedVector2Array:
	var mapping := PackedVector2Array()
	if not is_inside_tree():
		return mapping
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return mapping
	var mountain_transform: Transform2D = (
			mountain.get_global_transform_with_canvas())
	var current_origin: Vector2 = mountain_transform * Vector2.ZERO
	var current_right: Vector2 = mountain_transform * Vector2(
			mountain.size.x, 0.0)
	var current_bottom: Vector2 = mountain_transform * Vector2(
			0.0, mountain.size.y)
	var current_anchor_size: Vector2 = Vector2(
			current_right.x - current_origin.x,
			current_bottom.y - current_origin.y)
	if (current_anchor_size.x <= 0.0 or current_anchor_size.y <= 0.0
			or base_draw_size.x <= 0.0 or base_draw_size.y <= 0.0):
		return mapping
	var mapping_scale := current_anchor_size / base_draw_size
	var stage_origin := current_origin - base_origin * mapping_scale
	var stage_size := design_size * mapping_scale
	mapping.append(stage_origin / viewport_size)
	mapping.append(stage_size / viewport_size)
	return mapping


func _build_topology_image(
		mountains: Array[TextureRect],
		glacier: TextureRect,
		stage_size: Vector2) -> Image:
	var topology: Image = Image.create(
			grid_size.x, grid_size.y, false, Image.FORMAT_RGBA8)
	var cell_size: Vector2 = stage_size / Vector2(grid_size)
	for x: int in grid_size.x:
		var screen_x: float = (float(x) + 0.5) * cell_size.x
		var shore_screen_y: float = fallback_horizon_y * stage_size.y
		var found_authored_shore := false
		for mountain: TextureRect in mountains:
			var mountain_image := mountain.texture.get_image()
			var draw_size := Vector2(
					mountain.size.x * mountain.scale.x,
					mountain.size.y * mountain.scale.y)
			if draw_size.x <= 0.0 or draw_size.y <= 0.0:
				continue
			var source_u := (screen_x - mountain.position.x) / draw_size.x
			if source_u < 0.0 or source_u >= 1.0:
				continue
			if mountain.flip_h:
				source_u = 1.0 - source_u
			var source_x := clampi(
					int(floor(source_u * float(mountain_image.get_width()))),
					0,
					mountain_image.get_width() - 1)
			var bottom_row := _find_bottom_alpha_row(mountain_image, source_x)
			if bottom_row < 0:
				continue
			var candidate_shore_y := mountain.position.y + (
					(float(bottom_row) + 1.0)
					/ float(mountain_image.get_height())) * draw_size.y
			shore_screen_y = (
					maxf(shore_screen_y, candidate_shore_y)
					if found_authored_shore else candidate_shore_y)
			found_authored_shore = true

		var glacier_shore_y := INF
		if glacier != null:
			glacier_shore_y = _layer_bottom_screen_y(glacier, screen_x)

		var visible_start_y: float = shore_screen_y - (
				float(shore_overlap_cells) * cell_size.y)
		var depth_denominator: float = maxf(
				stage_size.y - shore_screen_y, cell_size.y)
		for y: int in grid_size.y:
			var screen_y: float = (float(y) + 0.5) * cell_size.y
			var water_occupancy: float = (
					1.0 if screen_y >= visible_start_y else 0.0)
			var distance_cells: float = maxf(
					(screen_y - shore_screen_y) / cell_size.y, 0.0)
			var shore_distance: float = clampf(
					distance_cells / float(shore_distance_cells), 0.0, 1.0)
			var perspective_depth: float = clampf(
					(screen_y - shore_screen_y) / depth_denominator, 0.0, 1.0)
			var glacier_contact := 0.0
			if glacier_shore_y < INF and screen_y >= glacier_shore_y:
				var glacier_distance_cells := (
						(screen_y - glacier_shore_y) / cell_size.y)
				glacier_contact = 1.0 - smoothstep(
						0.0, float(glacier_contact_cells),
						glacier_distance_cells)
			topology.set_pixel(x, y, Color(
					water_occupancy, shore_distance,
					perspective_depth, glacier_contact))
	return topology


func _layer_bottom_screen_y(layer: TextureRect, screen_x: float) -> float:
	if layer.texture == null:
		return INF
	var image := layer.texture.get_image()
	if image == null or image.is_empty():
		return INF
	var draw_size := Vector2(
			layer.size.x * layer.scale.x,
			layer.size.y * layer.scale.y)
	if draw_size.x <= 0.0 or draw_size.y <= 0.0:
		return INF
	var source_u := (screen_x - layer.position.x) / draw_size.x
	if source_u < 0.0 or source_u >= 1.0:
		return INF
	if layer.flip_h:
		source_u = 1.0 - source_u
	var source_x := clampi(
			int(floor(source_u * float(image.get_width()))),
			0,
			image.get_width() - 1)
	var bottom_row := _find_bottom_alpha_row(image, source_x)
	if bottom_row < 0:
		return INF
	return layer.position.y + (
			(float(bottom_row) + 1.0) / float(image.get_height())) * draw_size.y


func _find_bottom_alpha_row(image: Image, x: int) -> int:
	for y: int in range(image.get_height() - 1, -1, -1):
		if image.get_pixel(x, y).a >= mountain_alpha_threshold:
			return y
	return -1
