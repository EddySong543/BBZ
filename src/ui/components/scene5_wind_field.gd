extends Node

signal gust_triggered(strength: float, direction: float)

@export var wind_layer_paths: Array[NodePath] = []
@export var ambient_particles_path: NodePath
@export var gust_particles_path: NodePath
@export_range(1.0, 32.0, 0.5) var response_reference: float = 16.0
@export_range(-1.0, 1.0, 0.1) var ambient_direction: float = 1.0
@export_range(0.2, 2.0, 0.01) var gust_duration: float = 1.35
@export_range(1.0, 4.0, 0.05) var recovery_power: float = 2.4

var _wind_materials: Array[ShaderMaterial] = []
var _ambient_particles: GPUParticles2D = null
var _gust_particles: GPUParticles2D = null
var _ambient_speed_scale: float = 1.0
var _gust_started_msec: int = 0
var _gust_peak: float = 0.0
var _gust_direction: float = 1.0
var _gust_active: bool = false


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
			register_external_material(layer.material as ShaderMaterial)
	_ambient_particles = get_node_or_null(ambient_particles_path) as GPUParticles2D
	if _ambient_particles:
		_ambient_speed_scale = _ambient_particles.speed_scale
	_gust_particles = get_node_or_null(gust_particles_path) as GPUParticles2D


func register_external_material(material: Material) -> void:
	if not material is ShaderMaterial:
		return
	var shader_material := material as ShaderMaterial
	if _wind_materials.has(shader_material):
		return
	_wind_materials.append(shader_material)
	shader_material.set_shader_parameter("gust_strength", 0.0)
	shader_material.set_shader_parameter("gust_direction", ambient_direction)


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
