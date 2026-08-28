class_name Scene8LakeTopology
extends Node

signal topology_rebuilt(texture: Texture2D)

## Builds the Scene8 lake occupancy data once from the authored far-mountain
## alpha. R = water occupancy, G = normalized water-side shore distance,
## B = per-column perspective depth. The same texture is bound to the water
## base, aurora reflection, and platform-contact materials.

@export var grid_size: Vector2i = Vector2i(320, 180)
@export var design_size: Vector2 = Vector2(1920.0, 1080.0)
@export_range(0.0, 1.0, 0.001) var mountain_alpha_threshold: float = 0.03
@export_range(0, 4, 1) var shore_overlap_cells: int = 2
@export_range(1, 64, 1) var shore_distance_cells: int = 24
@export_range(0.35, 0.75, 0.005) var fallback_horizon_y: float = 0.52
@export var far_mountain_path: NodePath = ^"../FarSnowfield"
@export var lake_path: NodePath = ^"../MirrorLake"
@export var reflection_path: NodePath = ^"../AuroraReflection"
@export var contact_path: NodePath = ^"../PlatformWaterContact"

var _mountain: TextureRect
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
		push_warning("Scene8LakeTopology: FarSnowfield path is invalid")
		return false
	var candidate_mountain: TextureRect = mountain_node as TextureRect
	if candidate_mountain.texture == null:
		push_warning("Scene8LakeTopology: FarSnowfield has no texture")
		return false
	var mountain_image: Image = candidate_mountain.texture.get_image()
	if mountain_image == null or mountain_image.is_empty():
		push_warning("Scene8LakeTopology: FarSnowfield image is unavailable")
		return false

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
			mountain_image, base_mountain_origin,
			base_mountain_draw_size, design_size)
	var candidate_texture: ImageTexture = ImageTexture.create_from_image(
			candidate_image)
	var current_mapping: PackedVector2Array = _calculate_current_mapping(
			candidate_mountain)
	if current_mapping.size() != 2:
		return false
	var base_origin_uv: Vector2 = base_mountain_origin / design_size
	var base_size_uv: Vector2 = base_mountain_draw_size / design_size
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
			_mountain)
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


func _resolve_shader_material(node_path: NodePath) -> ShaderMaterial:
	var target_node: Node = get_node_or_null(node_path)
	if not target_node is CanvasItem:
		return null
	var target: CanvasItem = target_node as CanvasItem
	if not target.material is ShaderMaterial:
		return null
	return target.material as ShaderMaterial


func _calculate_current_mapping(mountain: TextureRect) -> PackedVector2Array:
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
	var current_size: Vector2 = Vector2(
			current_right.x - current_origin.x,
			current_bottom.y - current_origin.y)
	if current_size.x <= 0.0 or current_size.y <= 0.0:
		return mapping
	mapping.append(current_origin / viewport_size)
	mapping.append(current_size / viewport_size)
	return mapping


func _build_topology_image(
		mountain_image: Image,
		base_mountain_origin: Vector2,
		base_mountain_draw_size: Vector2,
		stage_size: Vector2) -> Image:
	var topology: Image = Image.create(
			grid_size.x, grid_size.y, false, Image.FORMAT_RGBA8)
	var cell_size: Vector2 = stage_size / Vector2(grid_size)
	var mountain_width: int = mountain_image.get_width()
	var mountain_height: int = mountain_image.get_height()
	for x: int in grid_size.x:
		var screen_x: float = (float(x) + 0.5) * cell_size.x
		var source_u: float = (
				(screen_x - base_mountain_origin.x)
				/ base_mountain_draw_size.x)
		var shore_screen_y: float = fallback_horizon_y * stage_size.y
		if source_u >= 0.0 and source_u < 1.0:
			var source_x: int = clampi(
					int(floor(source_u * float(mountain_width))),
					0, mountain_width - 1)
			var bottom_row: int = _find_bottom_alpha_row(
					mountain_image, source_x)
			if bottom_row >= 0:
				shore_screen_y = base_mountain_origin.y + (
						(float(bottom_row) + 1.0)
						/ float(mountain_height)) * base_mountain_draw_size.y

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
			topology.set_pixel(x, y, Color(
					water_occupancy, shore_distance,
					perspective_depth, 1.0))
	return topology


func _find_bottom_alpha_row(image: Image, x: int) -> int:
	for y: int in range(image.get_height() - 1, -1, -1):
		if image.get_pixel(x, y).a >= mountain_alpha_threshold:
			return y
	return -1
