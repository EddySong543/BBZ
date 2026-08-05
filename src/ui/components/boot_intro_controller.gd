class_name BootIntroController
extends Node

signal intro_finished

@export_group("Energy Brush Impact")
@export_range(0.0, 1.0, 0.01) var flash_start_seconds: float = 0.12
@export_range(0.2, 0.8, 0.01) var flash_duration_seconds: float = 0.48
@export_range(0.0, 1.0, 0.01) var brush_start_seconds: float = 0.12
@export_range(0.0, 1.0, 0.01) var gold_start_seconds: float = 0.12
@export_range(0.0, 1.0, 0.01) var pressure_start_seconds: float = 0.14
@export_range(0.5, 3.0, 0.01) var brush_duration_seconds: float = 1.2
@export_range(0.5, 3.0, 0.01) var gold_duration_seconds: float = 1.2
@export_range(0.5, 3.0, 0.01) var pressure_duration_seconds: float = 1.2
@export_range(0.0, 1.0, 0.01) var initial_star_intensity: float = 0.42
@export_range(0.0, 1.0, 0.01) var initial_glow_intensity: float = 0.14

@export_group("Title And Prompt")
@export_range(0.0, 4.0, 0.01) var title_start_seconds: float = 0.12
@export_range(0.0, 4.0, 0.01) var prompt_start_seconds: float = 0.12
@export_range(0.4, 2.0, 0.01) var title_duration_seconds: float = 1.2
@export_range(0.4, 2.0, 0.01) var prompt_duration_seconds: float = 1.2
@export_range(1.0, 5.0, 0.01) var total_duration_seconds: float = 1.32

@onready var _character: BootCharacterIdle = $"../Character"
@onready var _title: BootTitleController = $"../TitleColumn"
@onready var _prompt: BootEnterPrompt = $"../EnterPrompt"
@onready var _blue_motion: BootBlueFlowMotion = (
	$"../BackgroundStage/BlueFlowMotion")
@onready var _pressure_motion: BootPressureMotion = (
	$"../BackgroundStage/PressureMotion")
@onready var _background_stage: Control = $"../BackgroundStage"
@onready var _boot_root: Control = $".."

var _master_tween: Tween
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


func _prepare_intro() -> void:
	if _prepared:
		return
	_prepared = true
	_character.prepare_intro()
	_title.prepare_intro()
	_prompt.prepare_intro()
	_blue_motion.prepare_intro()
	_pressure_motion.prepare_intro()
	_background_stage.modulate.a = 1.0
	_base_root_position = _boot_root.position
	_base_root_scale = _boot_root.scale
	_base_root_pivot = _boot_root.pivot_offset


func _apply_time(seconds: float) -> void:
	var flash_progress := _linear_progress(
		seconds,
		flash_start_seconds,
		flash_duration_seconds)
	var flash_envelope := sin(flash_progress * PI)
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
		seconds,
		brush_start_seconds,
		brush_duration_seconds)
	var gold_progress := _brush_stroke_progress(
		seconds,
		gold_start_seconds,
		gold_duration_seconds)
	var title_progress := _timeline_progress(
		seconds,
		title_start_seconds,
		title_duration_seconds)
	var pressure_opacity := _timeline_progress(
		seconds,
		pressure_start_seconds,
		pressure_duration_seconds)
	var prompt_progress := _timeline_progress(
		seconds,
		prompt_start_seconds,
		prompt_duration_seconds)

	_character.set_intro_state(
		1.0,
		star_intensity,
		glow_intensity,
		-1.0)
	_background_stage.modulate.a = 1.0
	_blue_motion.set_intro_progress(brush_progress)
	_pressure_motion.set_intro_progress(
		pressure_opacity,
		gold_progress)
	_title.set_intro_progress(title_progress)
	_prompt.set_intro_reveal(prompt_progress)


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
	return _linear_progress(
		seconds,
		start_seconds,
		duration_seconds)


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
	_prompt.finish_intro()
	_blue_motion.finish_intro()
	_pressure_motion.finish_intro()
	_background_stage.modulate.a = 1.0
	_boot_root.position = _base_root_position
	_boot_root.scale = _base_root_scale
	_boot_root.pivot_offset = _base_root_pivot
	intro_finished.emit()
