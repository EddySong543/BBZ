extends Node2D

const GRASS_TEXTURES: Array[Texture2D] = [
	preload("res://assets/scenes/scene9/scene9_grass_01.png"),
	preload("res://assets/scenes/scene9/scene9_grass_02.png"),
	preload("res://assets/scenes/scene9/scene9_grass_03.png"),
]
const ALPHA_BOTTOMS: Array[float] = [141.0, 144.0, 149.0]
const FIELD_LEFT: float = -170.0
const FIELD_RIGHT: float = 2090.0

@export_group("Distribution")
@export var distribution_seed: int = 90817
@export_range(0.75, 1.25, 0.01) var width_multiplier: float = 1.0
@export_range(0.5, 1.5, 0.01) var density_multiplier: float = 1.0


func _ready() -> void:
	_rebuild_grass_instances()


func _rebuild_grass_instances() -> void:
	_configure_band($FarGrass, 4, 625.0, 18.0, 0.16, 0.22, 101, 0.18)
	_configure_band($MidGrass, 3, 680.0, 20.0, 0.29, 0.40, 211, 0.50)
	_configure_band($NearGrass, 2, 755.0, 20.0, 0.48, 0.62, 307, 0.82)


func _configure_band(
		band: Node2D,
		base_count: int,
		root_y: float,
		root_jitter: float,
		minimum_scale: float,
		maximum_scale: float,
		band_seed: int,
		depth_value: float) -> void:
	var instance_count: int = maxi(1, roundi(base_count * density_multiplier))
	var total_band_instances: int = instance_count * GRASS_TEXTURES.size()
	for variant_index: int in GRASS_TEXTURES.size():
		var instances := band.get_child(variant_index) as MultiMeshInstance2D
		if instances == null:
			continue
		var texture: Texture2D = GRASS_TEXTURES[variant_index]
		instances.texture = texture
		instances.multimesh = _create_multimesh(
				texture,
				ALPHA_BOTTOMS[variant_index],
				instance_count,
				total_band_instances,
				variant_index,
				root_y,
				root_jitter,
				minimum_scale,
				maximum_scale,
				band_seed + variant_index * 1009,
				depth_value)


func _create_multimesh(
		texture: Texture2D,
		alpha_bottom: float,
		instance_count: int,
		total_band_instances: int,
		variant_index: int,
		root_y: float,
		root_jitter: float,
		minimum_scale: float,
		maximum_scale: float,
		seed_offset: int,
		depth_value: float) -> MultiMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(texture.get_width(), texture.get_height())
	quad.center_offset = Vector3(
			0.0, texture.get_height() * 0.5 - alpha_bottom, 0.0)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	multimesh.instance_count = instance_count
	multimesh.visible_instance_count = instance_count

	var random := RandomNumberGenerator.new()
	random.seed = distribution_seed + seed_offset
	for instance_index: int in instance_count:
		var slot_index: int = instance_index * GRASS_TEXTURES.size() + variant_index
		var slot_step: float = (FIELD_RIGHT - FIELD_LEFT) / float(total_band_instances)
		var normalized_slot: float = (
				float(slot_index) + 0.5) / float(total_band_instances)
		var root_x: float = lerpf(FIELD_LEFT, FIELD_RIGHT, normalized_slot)
		root_x += random.randf_range(-slot_step * 0.17, slot_step * 0.17)
		root_x = 960.0 + (root_x - 960.0) * width_multiplier
		var instance_root_y: float = root_y + random.randf_range(-root_jitter, root_jitter)
		var perspective_scale: float = random.randf_range(minimum_scale, maximum_scale)
		var rotation: float = random.randf_range(-0.035, 0.035)
		var transform := Transform2D(
				rotation,
				Vector2(perspective_scale, perspective_scale),
				0.0,
				Vector2(root_x, instance_root_y))
		multimesh.set_instance_transform_2d(instance_index, transform)
		multimesh.set_instance_custom_data(instance_index, Color(
				random.randf(),
				random.randf_range(0.15, 0.95),
				depth_value,
				random.randf()))
	return multimesh


func distribution_mode_for_testing() -> String:
	return "procedural_field_with_stratified_accent_clumps"
