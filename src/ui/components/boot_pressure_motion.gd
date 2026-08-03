extends Node

@export_range(2.0, 12.0, 0.1) var flow_period: float = 5.2
@export var animation_enabled: bool = true

@onready var gold_energy: TextureRect = $"../GoldEnergy"

var _animation_time: float = 0.0
var _gold_material: ShaderMaterial


func _ready() -> void:
	_cache_materials()
	_apply_motion()


func _process(delta: float) -> void:
	if not animation_enabled:
		return
	_animation_time = fposmod(_animation_time + delta, 120.0)
	_apply_motion()


func animation_time() -> float:
	return _animation_time


func _cache_materials() -> void:
	gold_energy.rotation = 0.0
	_gold_material = gold_energy.material as ShaderMaterial
	if _gold_material == null:
		push_error("Boot GoldEnergy requires a ShaderMaterial.")


func _apply_motion() -> void:
	if _gold_material == null:
		return
	_gold_material.set_shader_parameter(
		&"motion_time",
		_animation_time)
	_gold_material.set_shader_parameter(
		&"flow_period",
		flow_period)
