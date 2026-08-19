class_name BootTitleController
extends Control

signal flow_phase_changed(phase: float)

const TITLE_TEXTURE_SIZE := 252.0
const TITLE_GROUP_WIDTH := 726.0
const TITLE_PART_COUNT := 3
const FLOW_START_PIXELS: Array[float] = [224.5, 224.5, 215.5]
const FLOW_END_PIXELS: Array[float] = [63.5, 45.5, 45.5]
const GROUP_START_PIXELS: Array[float] = [456.0, 228.0, 0.0]
const GROUP_END_PIXELS: Array[float] = [726.0, 498.0, 270.0]

@export_group("Palette")
@export var face_color: Color = Color(
		0.956863, 0.964706, 0.972549, 1.0)
@export var structure_color: Color = Color(
		0.058824, 0.105882, 0.149020, 1.0)
@export var energy_color: Color = Color(
		0.929412, 0.650980, 0.227451, 1.0)
@export var energy_peak_color: Color = Color(
		1.0, 0.843137, 0.450980, 1.0)

@export_group("Engraving Flow")
@export_range(1.0, 12.0, 0.1) var flow_period_seconds: float = 8.4
@export_range(0.0, 0.8, 0.01) var flow_stagger_seconds: float = 0.40
@export_range(0.1, 4.5, 0.01) var flow_duration_seconds: float = 3.6
@export_range(0.05, 1.5, 0.01) var release_duration_seconds: float = 1.0
@export_range(1.0, 12.0, 1.0) var head_width_texels: float = 6.0
@export_range(4.0, 48.0, 1.0) var tail_length_texels: float = 28.0
@export_range(1.0, 8.0, 1.0) var flow_pixel_step_texels: float = 4.0
@export_range(2.0, 8.0, 1.0) var flow_value_steps: float = 3.0
@export_range(0.0, 1.0, 0.01) var structure_tint_strength: float = 0.42

@export_group("Opening Entry")
@export_range(0.001, 0.05, 0.001) var intro_reveal_feather: float = 0.012
@export_range(0.01, 0.30, 0.001) var intro_crack_peak_width: float = 0.11
@export_range(0.0, 0.20, 0.001) var intro_shadow_lag: float = 0.055
@export_range(0.0, 0.25, 0.001) var intro_english_delay: float = 0.052632

@export_group("Pointer Perspective")
@export_range(0.0, 10.0, 0.1) var pointer_yaw_degrees: float = 6.0
@export_range(0.0, 6.0, 0.1) var pointer_pitch_degrees: float = 2.5
@export_range(1.0, 12.0, 0.1) var pointer_smooth: float = 5.0

@onready var _bo_top: TextureRect = $BoTop
@onready var _bo_middle: TextureRect = $BoMiddle
@onready var _zan_bottom: TextureRect = $ZanBottom
@onready var _bo_top_shadow: TextureRect = $BoTopShadow
@onready var _bo_middle_shadow: TextureRect = $BoMiddleShadow
@onready var _zan_bottom_shadow: TextureRect = $ZanBottomShadow
@onready var _english_subtitle: TextureRect = $EnglishSubtitle
@onready var _english_subtitle_shadow: TextureRect = $EnglishSubtitleShadow

var _materials: Array[ShaderMaterial] = []
var _shadow_materials: Array[ShaderMaterial] = []
var _english_material: ShaderMaterial
var _english_shadow_material: ShaderMaterial
var _phase_tween: Tween
var _current_flow_phase: float = 0.0
var _pointer_tilt: Vector2 = Vector2.ZERO


func _ready() -> void:
	_cache_materials()
	if _materials.size() != 3:
		return
	_apply_shared_parameters()
	_start_phase_tween()
	_apply_pointer_tilt()


func _process(delta: float) -> void:
	var viewport_size := get_viewport_rect().size
	var target := Vector2.ZERO
	if viewport_size.x > 0.0 and viewport_size.y > 0.0:
		var mouse_position := get_viewport().get_mouse_position()
		target = Vector2(
			(mouse_position.x / viewport_size.x - 0.5) * 2.0,
			(mouse_position.y / viewport_size.y - 0.5) * 2.0)
		target.x = clampf(target.x, -1.0, 1.0)
		target.y = clampf(target.y, -1.0, 1.0)
	var response := 1.0 - exp(-maxf(pointer_smooth, 0.001) * delta)
	_pointer_tilt = _pointer_tilt.lerp(target, response)
	_apply_pointer_tilt()


func preview_pointer_tilt(normalized_pointer: Vector2) -> void:
	_pointer_tilt = Vector2(
		clampf(normalized_pointer.x, -1.0, 1.0),
		clampf(normalized_pointer.y, -1.0, 1.0))
	_apply_pointer_tilt()


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


func final_flow_release_seconds() -> float:
	return minf(
		float(TITLE_PART_COUNT - 1) * flow_stagger_seconds
			+ flow_duration_seconds
			+ release_duration_seconds,
		maxf(flow_period_seconds, 0.001),
	)


func prepare_intro() -> void:
	if _phase_tween != null and _phase_tween.is_valid():
		_phase_tween.kill()
	_set_flow_phase(0.0)
	set_intro_progress(0.0)


func set_intro_progress(progress: float) -> void:
	var safe_progress := clampf(progress, 0.0, 1.0)
	for shader_material: ShaderMaterial in _materials:
		shader_material.set_shader_parameter(
			&"intro_reveal_progress",
			safe_progress)
	for shader_material: ShaderMaterial in _shadow_materials:
		shader_material.set_shader_parameter(
			&"intro_reveal_progress",
			safe_progress)
	if _english_material != null:
		_english_material.set_shader_parameter(
			&"intro_reveal_progress",
			safe_progress)
	if _english_shadow_material != null:
		_english_shadow_material.set_shader_parameter(
			&"intro_reveal_progress",
			safe_progress)


func finish_intro() -> void:
	set_intro_progress(1.0)
	_start_phase_tween()


func _cache_materials() -> void:
	_materials.clear()
	_shadow_materials.clear()
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

	var shadow_nodes: Array[TextureRect] = [
		_zan_bottom_shadow,
		_bo_middle_shadow,
		_bo_top_shadow,
	]
	for shadow_node: TextureRect in shadow_nodes:
		var shader_material := shadow_node.material as ShaderMaterial
		if shader_material == null:
			push_error(
				"Boot title shadow %s requires a ShaderMaterial."
				% shadow_node.name)
			_shadow_materials.clear()
			return
		_shadow_materials.append(shader_material)

	_english_material = _english_subtitle.material as ShaderMaterial
	_english_shadow_material = (
		_english_subtitle_shadow.material as ShaderMaterial)
	if _english_material == null or _english_shadow_material == null:
		push_error("Boot English subtitle requires title ShaderMaterials.")


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
		shader_material.set_shader_parameter(&"flow_enabled", false)
		shader_material.set_shader_parameter(&"intro_shadow", false)
		shader_material.set_shader_parameter(&"intro_progress_delay", 0.0)
		shader_material.set_shader_parameter(
			&"intro_reveal_feather",
			intro_reveal_feather)
		shader_material.set_shader_parameter(
			&"intro_crack_peak_width",
			intro_crack_peak_width)
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
			&"flow_pixel_step_texels",
			flow_pixel_step_texels)
		shader_material.set_shader_parameter(
			&"flow_value_steps",
			flow_value_steps)
		shader_material.set_shader_parameter(
			&"structure_tint_strength",
			structure_tint_strength)
		shader_material.set_shader_parameter(
			&"flow_start_uv_x",
			FLOW_START_PIXELS[index] / TITLE_TEXTURE_SIZE)
		shader_material.set_shader_parameter(
			&"flow_end_uv_x",
			FLOW_END_PIXELS[index] / TITLE_TEXTURE_SIZE)
		shader_material.set_shader_parameter(
			&"group_x_min",
			GROUP_START_PIXELS[index] / TITLE_GROUP_WIDTH)
		shader_material.set_shader_parameter(
			&"group_x_max",
			GROUP_END_PIXELS[index] / TITLE_GROUP_WIDTH)
	for shadow_material: ShaderMaterial in _shadow_materials:
		shadow_material.set_shader_parameter(&"flow_enabled", false)
		shadow_material.set_shader_parameter(&"intro_shadow", true)
		shadow_material.set_shader_parameter(&"intro_progress_delay", 0.0)
		shadow_material.set_shader_parameter(
			&"intro_reveal_feather",
			intro_reveal_feather)
		shadow_material.set_shader_parameter(
			&"intro_shadow_lag",
			intro_shadow_lag)
	_apply_english_parameters(
		safe_period,
		normalized_flow_duration,
		normalized_release_duration)
	_apply_palette()
	_apply_pointer_tilt()


func _apply_pointer_tilt() -> void:
	var yaw_strength := tan(deg_to_rad(pointer_yaw_degrees))
	var pitch_strength := tan(deg_to_rad(pointer_pitch_degrees))
	for shader_material: ShaderMaterial in (
			_materials + _shadow_materials):
		shader_material.set_shader_parameter(
			&"pointer_yaw",
			_pointer_tilt.x)
		shader_material.set_shader_parameter(
			&"pointer_pitch",
			_pointer_tilt.y)
		shader_material.set_shader_parameter(
			&"pointer_yaw_strength",
			yaw_strength)
		shader_material.set_shader_parameter(
			&"pointer_pitch_strength",
			pitch_strength)
	for shader_material: ShaderMaterial in [
		_english_material,
		_english_shadow_material,
	]:
		if shader_material == null:
			continue
		shader_material.set_shader_parameter(
			&"pointer_yaw",
			_pointer_tilt.x)
		shader_material.set_shader_parameter(
			&"pointer_pitch",
			_pointer_tilt.y)
		shader_material.set_shader_parameter(
			&"pointer_yaw_strength",
			yaw_strength)
		shader_material.set_shader_parameter(
			&"pointer_pitch_strength",
			pitch_strength)


func _apply_english_parameters(
	safe_period: float,
	normalized_flow_duration: float,
	normalized_release_duration: float,
) -> void:
	if _english_material == null or _english_shadow_material == null:
		return
	_english_material.set_shader_parameter(
		&"flow_enabled",
		true)
	_english_material.set_shader_parameter(
		&"flow_delay",
		0.12 / safe_period)
	_english_material.set_shader_parameter(
		&"flow_duration",
		normalized_flow_duration)
	_english_material.set_shader_parameter(
		&"release_duration",
		normalized_release_duration)
	_english_material.set_shader_parameter(
		&"head_width_texels",
		maxf(head_width_texels - 1.0, 1.0))
	_english_material.set_shader_parameter(
		&"tail_length_texels",
		maxf(tail_length_texels - 4.0, 4.0))
	_english_material.set_shader_parameter(
		&"flow_pixel_step_texels",
		flow_pixel_step_texels)
	_english_material.set_shader_parameter(
		&"flow_value_steps",
		flow_value_steps)
	_english_material.set_shader_parameter(
		&"structure_tint_strength",
		structure_tint_strength)
	_english_material.set_shader_parameter(
		&"intro_reveal_feather",
		intro_reveal_feather)
	_english_material.set_shader_parameter(
		&"intro_crack_peak_width",
		intro_crack_peak_width)
	_english_material.set_shader_parameter(&"intro_shadow", false)
	_english_material.set_shader_parameter(
		&"intro_progress_delay",
		intro_english_delay)
	_english_material.set_shader_parameter(&"flow_start_uv_x", 0.98)
	_english_material.set_shader_parameter(&"flow_end_uv_x", 0.02)
	_english_material.set_shader_parameter(&"group_x_min", 0.0)
	_english_material.set_shader_parameter(&"group_x_max", 1.0)
	_english_shadow_material.set_shader_parameter(
		&"flow_enabled",
		false)
	_english_shadow_material.set_shader_parameter(
		&"intro_shadow",
		true)
	_english_shadow_material.set_shader_parameter(
		&"intro_progress_delay",
		intro_english_delay)
	_english_shadow_material.set_shader_parameter(
		&"intro_reveal_feather",
		intro_reveal_feather)
	_english_shadow_material.set_shader_parameter(
		&"intro_shadow_lag",
		intro_shadow_lag)


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
	if _english_material != null:
		_english_material.set_shader_parameter(&"face_color", face_color)
		_english_material.set_shader_parameter(
			&"structure_color",
			structure_color)
		_english_material.set_shader_parameter(
			&"energy_color",
			energy_color)
		_english_material.set_shader_parameter(
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
	if _english_material != null:
		_english_material.set_shader_parameter(
			&"flow_phase",
			_current_flow_phase)
	flow_phase_changed.emit(_current_flow_phase)
