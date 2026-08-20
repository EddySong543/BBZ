extends Node

const CLICK_STREAK_POOL_SIZE: int = 3

signal gust_triggered(strength: float, direction: float)
signal far_leaves_triggered(canvas_position: Vector2)
signal far_wheat_clicked(canvas_position: Vector2)

@export var wind_layer_paths: Array[NodePath] = []
@export var ambient_particles_path: NodePath
@export var gust_particles_path: NodePath
@export var click_input_target_path: NodePath
@export var near_layer_path: NodePath
@export var far_hit_layer_paths: Array[NodePath] = []
@export var click_leaf_paths: Array[NodePath] = []
@export_range(1.0, 32.0, 0.5) var response_reference: float = 16.0
@export_range(-1.0, 1.0, 0.1) var ambient_direction: float = 1.0
@export_range(0.2, 2.0, 0.01) var gust_duration: float = 1.35
@export_range(1.0, 4.0, 0.05) var recovery_power: float = 2.4
@export_range(0.0, 0.5, 0.01) var click_cooldown: float = 0.18
@export_range(48.0, 320.0, 8.0) var click_repeat_radius_px: float = 160.0

var _wind_materials: Array[ShaderMaterial] = []
var _far_hit_layers: Array[Control] = []
var _click_leaf_layers: Array[CPUParticles2D] = []
var _click_leaf_groups: Array[Array] = []
var _click_group_origins: Array[Vector2] = []
var _ambient_particles: GPUParticles2D = null
var _gust_particles: GPUParticles2D = null
var _click_input_target: Control = null
var _ambient_speed_scale: float = 1.0
var _gust_started_msec: int = 0
var _gust_peak: float = 0.0
var _gust_direction: float = 1.0
var _gust_active: bool = false
var _click_cooldown_until_msec: int = 0
var _hit_images: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	var battle_stage := get_parent() as BattleStage
	if battle_stage:
		battle_stage.battle_response_requested.connect(
				_on_battle_response_requested)
	for path: NodePath in wind_layer_paths:
		var layer := get_node_or_null(path) as CanvasItem
		if layer and layer.material is ShaderMaterial:
			_register_wind_material(layer.material as ShaderMaterial)
	for path: NodePath in far_hit_layer_paths:
		var far_layer := get_node_or_null(path) as Control
		if far_layer:
			_far_hit_layers.append(far_layer)
	for path: NodePath in click_leaf_paths:
		var particles := get_node_or_null(path) as CPUParticles2D
		if particles:
			_click_leaf_layers.append(particles)
	var disturbance_texture := _build_far_disturbance_texture()
	for particles: CPUParticles2D in _click_leaf_layers:
		particles.texture = disturbance_texture
	_build_click_streak_pool(disturbance_texture)
	_ambient_particles = get_node_or_null(ambient_particles_path) as GPUParticles2D
	if _ambient_particles:
		_ambient_speed_scale = _ambient_particles.speed_scale
	_gust_particles = get_node_or_null(gust_particles_path) as GPUParticles2D
	_click_input_target = get_node_or_null(click_input_target_path) as Control
	if _click_input_target:
		_click_input_target.gui_input.connect(_on_click_input_gui_input)
	elif not click_input_target_path.is_empty():
		push_warning(
				"Scene5WindField: missing click input target %s"
				% click_input_target_path)


func register_external_material(material: Material) -> void:
	if not material is ShaderMaterial:
		return
	var shader_material := material as ShaderMaterial
	_register_wind_material(shader_material)


func _register_wind_material(shader_material: ShaderMaterial) -> void:
	if _wind_materials.has(shader_material):
		return
	_wind_materials.append(shader_material)
	shader_material.set_shader_parameter("gust_strength", 0.0)
	shader_material.set_shader_parameter("gust_direction", ambient_direction)


func _on_click_input_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	var canvas_position := _click_input_target.get_global_transform_with_canvas() \
			* mouse_event.position
	try_trigger_at_canvas_position(canvas_position)


func try_trigger_at_canvas_position(canvas_position: Vector2) -> bool:
	if Time.get_ticks_msec() < _click_cooldown_until_msec:
		return false
	var near_layer := get_node_or_null(near_layer_path) as Control
	if near_layer and _texture_hit(near_layer, canvas_position):
		return false
	for far_layer: Control in _far_hit_layers:
		if _texture_hit(far_layer, canvas_position):
			return trigger_far_leaves(canvas_position)
	return false


func trigger_far_leaves(canvas_position: Vector2) -> bool:
	if _click_leaf_groups.size() != CLICK_STREAK_POOL_SIZE:
		return false
	_click_cooldown_until_msec = Time.get_ticks_msec() \
			+ roundi(click_cooldown * 1000.0)
	far_wheat_clicked.emit(canvas_position)
	for group_index: int in _click_leaf_groups.size():
		if _group_is_active(group_index) \
				and _click_group_origins[group_index].distance_to(
						canvas_position) <= click_repeat_radius_px:
			return true
	var free_group_index := -1
	for group_index: int in _click_leaf_groups.size():
		if not _group_is_active(group_index):
			free_group_index = group_index
			break
	if free_group_index < 0:
		return true
	var stage := get_parent() as BattleStage
	var local_origin := stage.get_global_transform_with_canvas().affine_inverse() \
			* canvas_position
	var particle_group := _click_leaf_groups[free_group_index]
	for index: int in particle_group.size():
		var particles := particle_group[index] as CPUParticles2D
		var layer_origin := local_origin + Vector2(
				(float(index) - 1.0) * 10.0,
				4.0 + float(index) * 4.0)
		stage.set_layer_base_position(particles, layer_origin)
		particles.restart()
	_click_group_origins[free_group_index] = canvas_position
	far_leaves_triggered.emit(canvas_position)
	return true


func get_streak_group_count() -> int:
	return _click_leaf_groups.size()


func get_active_streak_group_count() -> int:
	var active_count := 0
	for group_index: int in _click_leaf_groups.size():
		if _group_is_active(group_index):
			active_count += 1
	return active_count


func get_active_streak_origins() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for group_index: int in _click_leaf_groups.size():
		if _group_is_active(group_index):
			result.append(_click_group_origins[group_index])
	return result


func _build_click_streak_pool(disturbance_texture: Texture2D) -> void:
	_click_leaf_groups.clear()
	_click_group_origins.clear()
	var depth_count := 3
	if _click_leaf_layers.size() != CLICK_STREAK_POOL_SIZE * depth_count:
		return
	for pool_index: int in CLICK_STREAK_POOL_SIZE:
		var particle_group: Array = []
		for depth_index: int in depth_count:
			var particles := _click_leaf_layers[
					pool_index * depth_count + depth_index]
			particles.texture = disturbance_texture
			particle_group.append(particles)
		_click_leaf_groups.append(particle_group)
		_click_group_origins.append(Vector2.ZERO)


func _group_is_active(group_index: int) -> bool:
	if group_index < 0 or group_index >= _click_leaf_groups.size():
		return false
	for particle_value: Variant in _click_leaf_groups[group_index]:
		var particles := particle_value as CPUParticles2D
		if particles != null and particles.emitting:
			return true
	return false


func _build_far_disturbance_texture() -> ImageTexture:
	# A low, torn horizontal streak reads as a small break in the wheat wave.
	# The asymmetric rows keep it from turning into a circular mote at distance.
	var image := Image.create(6, 3, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for point: Vector2i in [
		Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
		Vector2i(3, 1), Vector2i(4, 1),
		Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2),
	]:
		image.set_pixelv(point, Color.WHITE)
	return ImageTexture.create_from_image(image)


func _texture_hit(layer: Control, canvas_position: Vector2) -> bool:
	var local := layer.get_global_transform_with_canvas().affine_inverse() \
			* canvas_position
	if not Rect2(Vector2.ZERO, layer.size).has_point(local):
		return false
	var texture := layer.get("texture") as Texture2D
	if texture == null:
		return false
	var texture_id := texture.get_instance_id()
	var image := _hit_images.get(texture_id) as Image
	if image == null:
		image = texture.get_image()
		if image != null:
			_hit_images[texture_id] = image
	if image == null or image.is_empty():
		return false
	var uv := local / layer.size
	var material := layer.material as ShaderMaterial
	if material and float(material.get_shader_parameter("mirror_texture")) > 0.5:
		uv.x = 1.0 - uv.x
	var pixel := Vector2i(
			clampi(floori(uv.x * float(image.get_width())), 0, image.get_width() - 1),
			clampi(floori(uv.y * float(image.get_height())), 0, image.get_height() - 1))
	return image.get_pixelv(pixel).a >= 0.12


func trigger_battle_gust(strength: float, direction: float = 0.0) -> void:
	var normalized := clampf(strength / response_reference, 0.28, 1.0)
	var resolved_direction := signf(direction)
	_gust_started_msec = Time.get_ticks_msec()
	_gust_peak = normalized
	_gust_direction = resolved_direction
	_gust_active = true
	set_process(true)
	_set_gust(normalized, resolved_direction)
	if _ambient_particles:
		_ambient_particles.speed_scale = _ambient_speed_scale * 0.16
	_emit_gust_chaff(normalized, resolved_direction)
	gust_triggered.emit(normalized, resolved_direction)


func _process(_delta: float) -> void:
	if not _gust_active:
		return
	var elapsed := float(Time.get_ticks_msec() - _gust_started_msec) / 1000.0
	var progress := clampf(elapsed / gust_duration, 0.0, 1.0)
	var strength := _gust_peak * response_strength_at(progress)
	_set_gust(strength, _gust_direction)
	if progress >= 1.0:
		_gust_active = false
		set_process(false)
		if _ambient_particles:
			_ambient_particles.speed_scale = _ambient_speed_scale


func _on_battle_response_requested(strength: float, direction: float) -> void:
	trigger_battle_gust(strength, direction)


func response_strength_at(progress: float) -> float:
	return pow(1.0 - clampf(progress, 0.0, 1.0), recovery_power)


func _set_gust(strength: float, direction: float) -> void:
	for material: ShaderMaterial in _wind_materials:
		material.set_shader_parameter("gust_strength", strength)
		material.set_shader_parameter("gust_direction", direction)


func _emit_gust_chaff(strength: float, direction: float) -> void:
	if _gust_particles == null:
		return
	var process_material := (
			_gust_particles.process_material as ParticleProcessMaterial)
	if process_material:
		# BattleStage can briefly report the inherited StageSlot width before its
		# 1920-wide authored canvas finishes layout; the scene contract is fixed
		# at 1920, so never derive an edge emitter from that transient small size.
		var stage_width := maxf((get_parent() as Control).size.x, 1920.0)
		var source_position := _gust_particles.position
		if direction > 0.0:
			source_position.x = stage_width * 0.14
			process_material.emission_box_extents.x = stage_width * 0.2
		elif direction < 0.0:
			source_position.x = stage_width * 0.86
			process_material.emission_box_extents.x = stage_width * 0.2
		else:
			source_position.x = stage_width * 0.5
			process_material.emission_box_extents.x = stage_width * 0.42
		var battle_stage := get_parent() as BattleStage
		battle_stage.set_layer_base_position(_gust_particles, source_position)
		process_material.direction = Vector3(direction, -0.08, 0.0)
		process_material.gravity = Vector3(direction * 5.0, 1.5, 0.0)
		process_material.initial_velocity_min = lerpf(130.0, 165.0, strength)
		process_material.initial_velocity_max = lerpf(180.0, 210.0, strength)
	_gust_particles.emitting = true
	_gust_particles.restart()
