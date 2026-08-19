class_name BootPressureMotion
extends Node

@export_range(2.0, 12.0, 0.1) var flow_period: float = 5.2
@export_range(12.0, 60.0, 0.5) var contour_period: float = 44.0
@export var animation_enabled: bool = true

@onready var pressure_contours: ColorRect = $"../PressureContours"
@onready var gold_energy: TextureRect = $"../GoldEnergy"

var _animation_time: float = 0.0
var _speed_multiplier: float = 1.0
var _contour_material: ShaderMaterial
var _gold_material: ShaderMaterial


func _ready() -> void:
	_cache_materials()
	_apply_motion()


func _process(delta: float) -> void:
	if not animation_enabled:
		return
	_animation_time = fposmod(
		_animation_time + delta * _speed_multiplier,
		120.0)
	_apply_motion()


func animation_time() -> float:
	return _animation_time


func set_speed_multiplier(multiplier: float) -> void:
	_speed_multiplier = maxf(multiplier, 0.0)


func prepare_intro() -> void:
	animation_enabled = true
	_animation_time = 0.0
	_apply_motion()
	set_intro_progress(0.0, 0.0)


func set_intro_progress(
		contour_progress: float,
		gold_progress: float,
) -> void:
	if _contour_material != null:
		_contour_material.set_shader_parameter(
			&"intro_opacity",
			clampf(contour_progress, 0.0, 1.0))
	if _gold_material != null:
		_gold_material.set_shader_parameter(
			&"intro_path_progress",
			clampf(gold_progress, 0.0, 1.0))


func finish_intro() -> void:
	set_intro_progress(1.0, 1.0)
	_speed_multiplier = 1.0
	animation_enabled = true


func _cache_materials() -> void:
	gold_energy.rotation = 0.0
	_contour_material = pressure_contours.material as ShaderMaterial
	_gold_material = gold_energy.material as ShaderMaterial
	if _contour_material == null:
		push_error("Boot PressureContours requires a ShaderMaterial.")
	if _gold_material == null:
		push_error("Boot GoldEnergy requires a ShaderMaterial.")


func _apply_motion() -> void:
	if _contour_material != null:
		_contour_material.set_shader_parameter(
			&"motion_time",
			_animation_time)
		_contour_material.set_shader_parameter(
			&"wave_period",
			contour_period)
	if _gold_material != null:
		_gold_material.set_shader_parameter(
			&"motion_time",
			_animation_time)
		_gold_material.set_shader_parameter(
			&"flow_period",
			flow_period)
