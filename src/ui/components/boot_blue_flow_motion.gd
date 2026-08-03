extends Node

@export var animation_enabled: bool = true

@onready var blue_base: TextureRect = $"../BlueBase"
@onready var blue_mid: TextureRect = $"../BlueMid"
@onready var blue_light: TextureRect = $"../BlueLight"

var _animation_time: float = 0.0
var _blue_materials: Array[ShaderMaterial] = []


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


func _apply_motion_time() -> void:
	for shader_material: ShaderMaterial in _blue_materials:
		shader_material.set_shader_parameter(
			&"motion_time",
			_animation_time)
