extends Control

const TITLE_TEXTURE_SIZE := 252.0
const TITLE_GROUP_WIDTH := 801.4
const FLOW_START_PIXELS: Array[float] = [63.5, 45.5, 45.5]
const FLOW_END_PIXELS: Array[float] = [224.5, 224.5, 215.5]
const FRAGMENT_ORIGIN_Y_PIXELS: Array[float] = [78.5, 78.5, 90.5]
const GROUP_START_PIXELS: Array[float] = [499.0, 250.0, 0.0]
const GROUP_END_PIXELS: Array[float] = [801.4, 552.4, 302.4]

@export_group("Palette")
@export var face_color: Color = Color(
		0.960784, 0.909804, 0.819608, 1.0)
@export var structure_color: Color = Color(
		0.058824, 0.105882, 0.149020, 1.0)
@export var energy_color: Color = Color(
		0.886275, 0.364706, 0.286275, 1.0)
@export var energy_peak_color: Color = Color(
		0.960784, 0.909804, 0.819608, 1.0)

@export_group("Engraving Flow")
@export_range(1.0, 8.0, 0.1) var flow_period_seconds: float = 4.2
@export_range(0.0, 0.8, 0.01) var flow_stagger_seconds: float = 0.28
@export_range(0.1, 2.5, 0.01) var flow_duration_seconds: float = 1.35
@export_range(0.05, 1.5, 0.01) var release_duration_seconds: float = 0.70
@export_range(1.0, 12.0, 1.0) var head_width_texels: float = 6.0
@export_range(4.0, 48.0, 1.0) var tail_length_texels: float = 28.0
@export_range(0.0, 1.0, 0.01) var structure_tint_strength: float = 0.42
@export_range(0.0, 1.0, 0.01) var fragment_strength: float = 0.85

@onready var _bo_top: TextureRect = $BoTop
@onready var _bo_middle: TextureRect = $BoMiddle
@onready var _zan_bottom: TextureRect = $ZanBottom

var _materials: Array[ShaderMaterial] = []
var _phase_tween: Tween
var _current_flow_phase: float = 0.0


func _ready() -> void:
	_cache_materials()
	if _materials.size() != 3:
		return
	_apply_shared_parameters()
	_start_phase_tween()


func apply_palette(
		new_face_color: Color,
		new_structure_color: Color,
		new_energy_color: Color,
		new_energy_peak_color: Color,
) -> void:
	face_color = new_face_color
	structure_color = new_structure_color
	energy_color = new_energy_color
	energy_peak_color = new_energy_peak_color
	_apply_palette()


func current_flow_phase() -> float:
	return _current_flow_phase


func _cache_materials() -> void:
	_materials.clear()
	var title_nodes: Array[TextureRect] = [
		_zan_bottom,
		_bo_middle,
		_bo_top,
	]
	for title_node: TextureRect in title_nodes:
		var shader_material := title_node.material as ShaderMaterial
		if shader_material == null:
			push_error(
				"Boot title node %s requires a ShaderMaterial."
				% title_node.name)
			_materials.clear()
			return
		_materials.append(shader_material)


func _apply_shared_parameters() -> void:
	var safe_period := maxf(flow_period_seconds, 0.001)
	var normalized_flow_duration := clampf(
		flow_duration_seconds / safe_period,
		0.001,
		0.5)
	var normalized_release_duration := clampf(
		release_duration_seconds / safe_period,
		0.001,
		0.25)

	for index: int in _materials.size():
		var shader_material := _materials[index]
		shader_material.set_shader_parameter(
			&"flow_delay",
			float(index) * flow_stagger_seconds / safe_period)
		shader_material.set_shader_parameter(
			&"flow_duration",
			normalized_flow_duration)
		shader_material.set_shader_parameter(
			&"release_duration",
			normalized_release_duration)
		shader_material.set_shader_parameter(
			&"head_width_texels",
			head_width_texels)
		shader_material.set_shader_parameter(
			&"tail_length_texels",
			tail_length_texels)
		shader_material.set_shader_parameter(
			&"structure_tint_strength",
			structure_tint_strength)
		shader_material.set_shader_parameter(
			&"fragment_strength",
			fragment_strength)
		shader_material.set_shader_parameter(
			&"flow_start_uv_x",
			FLOW_START_PIXELS[index] / TITLE_TEXTURE_SIZE)
		shader_material.set_shader_parameter(
			&"flow_end_uv_x",
			FLOW_END_PIXELS[index] / TITLE_TEXTURE_SIZE)
		shader_material.set_shader_parameter(
			&"fragment_origin_uv_y",
			FRAGMENT_ORIGIN_Y_PIXELS[index] / TITLE_TEXTURE_SIZE)
		shader_material.set_shader_parameter(
			&"group_x_min",
			GROUP_START_PIXELS[index] / TITLE_GROUP_WIDTH)
		shader_material.set_shader_parameter(
			&"group_x_max",
			GROUP_END_PIXELS[index] / TITLE_GROUP_WIDTH)
	_apply_palette()


func _apply_palette() -> void:
	for shader_material: ShaderMaterial in _materials:
		shader_material.set_shader_parameter(&"face_color", face_color)
		shader_material.set_shader_parameter(
			&"structure_color",
			structure_color)
		shader_material.set_shader_parameter(&"energy_color", energy_color)
		shader_material.set_shader_parameter(
			&"energy_peak_color",
			energy_peak_color)


func _start_phase_tween() -> void:
	_set_flow_phase(0.0)
	if _phase_tween != null and _phase_tween.is_valid():
		_phase_tween.kill()
	_phase_tween = create_tween()
	_phase_tween.set_loops()
	_phase_tween.tween_method(
		_set_flow_phase,
		0.0,
		1.0,
		maxf(flow_period_seconds, 0.001),
	).set_trans(Tween.TRANS_LINEAR)


func _set_flow_phase(phase: float) -> void:
	_current_flow_phase = clampf(phase, 0.0, 1.0)
	for shader_material: ShaderMaterial in _materials:
		shader_material.set_shader_parameter(
			&"flow_phase",
			_current_flow_phase)
