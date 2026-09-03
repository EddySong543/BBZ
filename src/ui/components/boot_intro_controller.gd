class_name BootIntroController
extends Node

signal intro_finished

@export_group("Energy Brush Impact")
@export_range(0.0, 1.0, 0.01) var flash_start_seconds: float = 0.04
@export_range(0.2, 0.8, 0.01) var flash_duration_seconds: float = 0.38
@export_range(0.0, 1.0, 0.01) var brush_start_seconds: float = 0.12
@export_range(0.0, 1.0, 0.01) var gold_start_seconds: float = 0.12
@export_range(0.0, 1.0, 0.01) var pressure_start_seconds: float = 0.28
@export_range(0.5, 3.0, 0.01) var brush_duration_seconds: float = 0.72
@export_range(0.5, 3.0, 0.01) var gold_duration_seconds: float = 0.92
@export_range(0.5, 3.0, 0.01) var pressure_duration_seconds: float = 0.70
@export_range(0.0, 1.0, 0.01) var initial_star_intensity: float = 0.42
@export_range(0.0, 1.0, 0.01) var initial_glow_intensity: float = 0.14

@export_group("Impact Propagation Timing")
@export_range(0.0, 1.0, 0.01) var impact_propagation_start_seconds: float = 0.18
@export_range(0.2, 1.2, 0.01) var impact_propagation_end_seconds: float = 0.88
@export_range(0.02, 0.2, 0.01) var impact_propagation_lead_seconds: float = 0.12
@export_range(0.01, 0.12, 0.01) var impact_support_lead_seconds: float = 0.06

@export_group("Title And Prompt")
@export_range(0.0, 4.0, 0.01) var title_start_seconds: float = 0.12
@export_range(0.0, 4.0, 0.01) var prompt_start_seconds: float = 0.12
@export_range(0.4, 2.0, 0.01) var title_duration_seconds: float = 0.76
@export_range(0.4, 2.0, 0.01) var prompt_duration_seconds: float = 0.94
@export_range(1.0, 5.0, 0.01) var total_duration_seconds: float = 1.32

@onready var _character: BootCharacterIdle = $"../Character"
@onready var _title: BootTitleController = $"../TitleColumn"
@onready var _menu: BootMenuController = $"../InterfaceLayer/BootMenu"
@onready var _blue_motion: BootBlueFlowMotion = (
	$"../BackgroundStage/BlueFlowMotion")
@onready var _pressure_motion: BootPressureMotion = (
	$"../BackgroundStage/PressureMotion")
@onready var _background_stage: Control = $"../BackgroundStage"
@onready var _boot_root: Control = $".."

var _master_tween: Tween
var _exit_tween: Tween
var _prepared: bool = false
var _finished: bool = false
var _base_root_position: Vector2
var _base_root_scale: Vector2
var _base_root_pivot: Vector2


func flash_count() -> int:
	return 1


func is_finished() -> bool:
	return _finished


func play_intro() -> void:
	_prepare_intro()
	_finished = false
	_apply_time(0.0)
	if _master_tween != null and _master_tween.is_valid():
		_master_tween.kill()
	_master_tween = create_tween()
	_master_tween.tween_method(
		_apply_time,
		0.0,
		total_duration_seconds,
		total_duration_seconds,
	).set_trans(Tween.TRANS_LINEAR)
	_master_tween.tween_callback(_finish_intro)


func preview_at_time(seconds: float) -> void:
	_prepare_intro()
	_finished = false
	if _master_tween != null and _master_tween.is_valid():
		_master_tween.kill()
	_apply_time(clampf(seconds, 0.0, total_duration_seconds))
	if seconds >= total_duration_seconds:
		_finish_intro()


func finish_immediately() -> void:
	_prepare_intro()
	if _master_tween != null and _master_tween.is_valid():
		_master_tween.kill()
	_apply_time(total_duration_seconds)
	_finish_intro()


func play_exit_impulse() -> void:
	_prepare_intro()
	if _exit_tween != null and _exit_tween.is_valid():
		_exit_tween.kill()
	_blue_motion.set_speed_multiplier(3.0)
	_pressure_motion.set_speed_multiplier(2.6)
	_exit_tween = create_tween()
	_exit_tween.tween_method(
		_apply_exit_progress,
		0.0,
		1.0,
		0.52,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _prepare_intro() -> void:
	if _prepared:
		return
	_prepared = true
	_character.prepare_intro()
	_title.prepare_intro()
	_menu.prepare_intro()
	_blue_motion.prepare_intro()
	_pressure_motion.prepare_intro()
	_background_stage.modulate.a = 1.0
	_base_root_position = _boot_root.position
	_base_root_scale = _boot_root.scale
	_base_root_pivot = _boot_root.pivot_offset


func _apply_time(seconds: float) -> void:
	var impact_layer_seconds := _impact_layer_seconds(seconds)
	var support_layer_seconds := _impact_support_layer_seconds(seconds)
	var flash_progress := _linear_progress(
		seconds,
		flash_start_seconds,
		flash_duration_seconds)
	var flash_envelope := pow(
		maxf(sin(flash_progress * PI), 0.0),
		0.72)
	var star_intensity := lerpf(
		initial_star_intensity,
		1.90,
		flash_envelope)
	var glow_intensity := lerpf(
		initial_glow_intensity,
		1.10,
		flash_envelope)
	if seconds > flash_start_seconds + flash_duration_seconds:
		star_intensity = 1.0
		glow_intensity = 0.78

	var brush_progress := _brush_stroke_progress(
		impact_layer_seconds,
		brush_start_seconds,
		brush_duration_seconds)
	var gold_progress := _gold_path_progress(impact_layer_seconds)
	var title_progress := _title_activation_progress(support_layer_seconds)
	var pressure_opacity := _timeline_progress(
		support_layer_seconds,
		pressure_start_seconds,
		pressure_duration_seconds)
	var prompt_progress := _prompt_activation_progress(
		support_layer_seconds)

	_character.set_intro_state(
		1.0,
		star_intensity,
		glow_intensity,
		-1.0,
		flash_progress)
	_background_stage.modulate.a = 1.0
	_blue_motion.set_intro_progress(brush_progress)
	_pressure_motion.set_intro_progress(
		pressure_opacity,
		gold_progress)
	_title.set_intro_progress(title_progress)
	_menu.set_intro_reveal(prompt_progress)


func _apply_exit_progress(progress: float) -> void:
	var safe_progress := clampf(progress, 0.0, 1.0)
	_character.set_exit_release_progress(safe_progress)


func _impact_layer_seconds(seconds: float) -> float:
	return _propagated_layer_seconds(
		seconds,
		impact_propagation_lead_seconds)


func _impact_support_layer_seconds(seconds: float) -> float:
	return _propagated_layer_seconds(
		seconds,
		impact_support_lead_seconds)


func _propagated_layer_seconds(
		seconds: float,
		lead_seconds: float,
) -> float:
	var propagation_start := maxf(
		impact_propagation_start_seconds,
		0.0)
	var propagation_end := maxf(
		impact_propagation_end_seconds,
		propagation_start + 0.001)
	if seconds <= propagation_start or seconds >= propagation_end:
		return seconds

	var propagation_progress := clampf(
		(seconds - propagation_start)
			/ maxf(propagation_end - propagation_start, 0.001),
		0.0,
		1.0)
	var propagation_envelope := sin(propagation_progress * PI)
	return seconds + maxf(
		lead_seconds,
		0.0) * propagation_envelope


func _timeline_progress(
		seconds: float,
		start_seconds: float,
		duration_seconds: float,
) -> float:
	var linear := clampf(
		(seconds - start_seconds) / maxf(duration_seconds, 0.001),
		0.0,
		1.0)
	return smoothstep(0.0, 1.0, linear)


func _brush_stroke_progress(
		seconds: float,
		start_seconds: float,
		duration_seconds: float,
) -> float:
	var linear := _linear_progress(
		seconds,
		start_seconds,
		duration_seconds)
	if linear <= 0.18:
		return lerpf(
			0.0,
			0.08,
			_smooth_segment(linear, 0.0, 0.18))
	if linear <= 0.62:
		return lerpf(
			0.08,
			0.78,
			_smooth_segment(linear, 0.18, 0.62))
	return lerpf(
		0.78,
		1.0,
		_smooth_segment(linear, 0.62, 1.0))


func _gold_path_progress(seconds: float) -> float:
	var linear := _linear_progress(
		seconds,
		gold_start_seconds,
		gold_duration_seconds)
	if linear <= 0.20:
		return lerpf(
			0.0,
			0.06,
			_smooth_segment(linear, 0.0, 0.20))
	if linear <= 0.72:
		return lerpf(
			0.06,
			0.72,
			_smooth_segment(linear, 0.20, 0.72))
	return lerpf(
		0.72,
		1.0,
		_smooth_segment(linear, 0.72, 1.0))


func _title_activation_progress(seconds: float) -> float:
	var linear := _linear_progress(
		seconds,
		title_start_seconds,
		title_duration_seconds)
	if linear <= 0.12:
		return lerpf(
			0.0,
			0.04,
			_smooth_segment(linear, 0.0, 0.12))
	if linear <= 0.72:
		return lerpf(
			0.04,
			0.86,
			_smooth_segment(linear, 0.12, 0.72))
	return lerpf(
		0.86,
		1.0,
		_smooth_segment(linear, 0.72, 1.0))


func _prompt_activation_progress(seconds: float) -> float:
	var linear := _linear_progress(
		seconds,
		prompt_start_seconds,
		prompt_duration_seconds)
	return smoothstep(0.0, 1.0, linear)


func _smooth_segment(
		value: float,
		start_value: float,
		end_value: float,
) -> float:
	var normalized := clampf(
		inverse_lerp(start_value, end_value, value),
		0.0,
		1.0)
	return smoothstep(0.0, 1.0, normalized)


func _linear_progress(
		seconds: float,
		start_seconds: float,
		duration_seconds: float,
) -> float:
	return clampf(
		(seconds - start_seconds) / maxf(duration_seconds, 0.001),
		0.0,
		1.0)


func _finish_intro() -> void:
	if _finished:
		return
	_finished = true
	_character.finish_intro()
	_title.finish_intro()
	_menu.finish_intro()
	_blue_motion.finish_intro()
	_pressure_motion.finish_intro()
	_background_stage.modulate.a = 1.0
	_boot_root.position = _base_root_position
	_boot_root.scale = _base_root_scale
	_boot_root.pivot_offset = _base_root_pivot
	intro_finished.emit()
