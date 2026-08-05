class_name BootBlueFlowMotion
extends Node

@export var animation_enabled: bool = true

@onready var blue_base: TextureRect = $"../BlueBase"
@onready var blue_mid: TextureRect = $"../BlueMid"
@onready var blue_light: TextureRect = $"../BlueLight"
@onready var foreground_brush: TextureRect = $"../ForegroundBrush"

var _animation_time: float = 0.0
var _blue_materials: Array[ShaderMaterial] = []
var _foreground_material: ShaderMaterial


func _ready() -> void:
	_cache_materials()
	_apply_motion_time()


func _process(delta: float) -> void:
	if not animation_enabled:
		return
	_animation_time = fposmod(_animation_time + delta, 120.0)
	_apply_motion_time()


func animation_time() -> float:
	return _animation_time


func prepare_intro() -> void:
	animation_enabled = true
	_animation_time = 0.0
	_apply_motion_time()
	set_intro_progress(0.0)


func set_intro_progress(progress: float) -> void:
	var safe_progress := clampf(progress, 0.0, 1.0)
	for shader_material: ShaderMaterial in _blue_materials:
		shader_material.set_shader_parameter(
			&"intro_stroke_progress",
			safe_progress)
	if _foreground_material != null:
		_foreground_material.set_shader_parameter(
			&"intro_stroke_progress",
			safe_progress)


func finish_intro() -> void:
	set_intro_progress(1.0)
	animation_enabled = true


func _cache_materials() -> void:
	_blue_materials.clear()
	for layer: TextureRect in [blue_base, blue_mid, blue_light]:
		var shader_material := layer.material as ShaderMaterial
		if shader_material == null:
			push_error(
				"Boot blue layer %s requires a ShaderMaterial."
				% layer.name)
			_blue_materials.clear()
			return
		_blue_materials.append(shader_material)
	_foreground_material = foreground_brush.material as ShaderMaterial
	if _foreground_material == null:
		push_error(
			"Boot ForegroundBrush requires a ShaderMaterial.")


func _apply_motion_time() -> void:
	for shader_material: ShaderMaterial in _blue_materials:
		shader_material.set_shader_parameter(
			&"motion_time",
			_animation_time)
