class_name MainHubPortalRig
extends Control

signal energy_state_changed(level: float, color: Color)

const PORTAL_FLOAT_AMPLITUDE: float = 3.0
const PORTAL_FLOAT_PERIOD: float = 3.8
const SEARCH_ENERGY_LEVEL: float = 0.34
const ENERGY_TWEEN_DURATION: float = 0.38

var _stones: Array[TextureRect] = []
var _stone_bases: PackedVector2Array = PackedVector2Array()
var _stone_materials: Array[ShaderMaterial] = []
var _anim_time: float = 0.0
var _energy_level: float = 0.0
var _energy_color: Color = Color.WHITE
var _energy_tween: Tween


func _ready() -> void:
	for child: Node in get_children():
		if child is TextureRect and child.name.begins_with("PortalStone"):
			var stone := child as TextureRect
			_stones.append(stone)
			_stone_bases.append(stone.position)
			var material := stone.material as ShaderMaterial
			if material != null:
				_stone_materials.append(material)
	set_process(true)


func get_stones() -> Array[TextureRect]:
	return _stones.duplicate()


func begin_search(color: Color) -> void:
	_animate_energy(SEARCH_ENERGY_LEVEL, color)


func complete_connection(color: Color) -> void:
	_animate_energy(1.0, color)


func reset_energy() -> void:
	_animate_energy(0.0, Color.WHITE)


func get_energy_level() -> float:
	return _energy_level


func _animate_energy(target_level: float, color: Color) -> void:
	_energy_color = color
	if _energy_tween != null and _energy_tween.is_valid():
		_energy_tween.kill()
	_energy_tween = create_tween()
	_energy_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_energy_tween.tween_method(_set_energy_level, _energy_level,
			clampf(target_level, 0.0, 1.0), ENERGY_TWEEN_DURATION)


func _set_energy_level(value: float) -> void:
	_energy_level = clampf(value, 0.0, 1.0)
	for material: ShaderMaterial in _stone_materials:
		material.set_shader_parameter("energy_color", _energy_color)
		material.set_shader_parameter("energy_mix", _energy_level)
	energy_state_changed.emit(_energy_level, _energy_color)


func _process(delta: float) -> void:
	_anim_time += delta
	var stone_count: int = _stones.size()
	if stone_count == 0:
		return
	for index: int in stone_count:
		var phase: float = float(index) * TAU / float(stone_count)
		var lift: float = sin(_anim_time * TAU / PORTAL_FLOAT_PERIOD + phase) \
				* PORTAL_FLOAT_AMPLITUDE
		_stones[index].position = _stone_bases[index] + Vector2(0.0, lift)
		if index < _stone_materials.size():
			_stone_materials[index].set_shader_parameter("anim_time", _anim_time)
