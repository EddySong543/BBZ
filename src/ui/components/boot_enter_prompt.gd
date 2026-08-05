class_name BootEnterPrompt
extends Control

@export_range(0.5, 4.0, 0.1) var fade_duration: float = 1.8
@export_range(0.0, 1.0, 0.01) var minimum_alpha: float = 0.84
@export_range(16, 40, 1) var font_size: int = 28

@export_group("Title Sync")
@export_range(0.1, 1.5, 0.05) var title_peak_delay_seconds: float = 0.5

@export_group("Enter Feedback")
@export_range(0.9, 1.0, 0.005) var enter_feedback_scale: float = 0.975

@onready var _label: Label = $Label

var _fade_tween: Tween
var _synced_title: BootTitleController
var _title_flow_period_seconds: float = 0.0
var _title_flow_end_seconds: float = 0.0
var _enter_feedback_active: bool = false
var _intro_active: bool = false


func _ready() -> void:
	FontManager.apply(_label, font_size)
	_start_fade_loop()


func synchronize_with_title(title: BootTitleController) -> void:
	if (
		_synced_title != null
		and is_instance_valid(_synced_title)
		and _synced_title.flow_phase_changed.is_connected(
			_on_title_flow_phase_changed)
	):
		_synced_title.flow_phase_changed.disconnect(
			_on_title_flow_phase_changed)

	_synced_title = title
	_title_flow_period_seconds = maxf(
		title.flow_period_seconds,
		0.001)
	_title_flow_end_seconds = title.final_flow_release_seconds()
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	title.flow_phase_changed.connect(_on_title_flow_phase_changed)
	_on_title_flow_phase_changed(title.current_flow_phase())


func is_title_synchronized() -> bool:
	return (
		_synced_title != null
		and is_instance_valid(_synced_title)
		and _synced_title.flow_phase_changed.is_connected(
			_on_title_flow_phase_changed)
	)


func synced_peak_phase() -> float:
	if _title_flow_period_seconds <= 0.0:
		return 0.0
	return (
		minf(
			_title_flow_end_seconds + title_peak_delay_seconds,
			_title_flow_period_seconds - 0.001,
		)
		/ _title_flow_period_seconds
	)


func play_enter_feedback() -> void:
	_enter_feedback_active = true
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	modulate.a = 1.0
	scale = Vector2.ONE * enter_feedback_scale


func prepare_intro() -> void:
	_intro_active = true
	_enter_feedback_active = false
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	visible = false
	modulate.a = 0.0
	scale = Vector2.ONE


func set_intro_reveal(progress: float) -> void:
	var safe_progress := clampf(progress, 0.0, 1.0)
	visible = safe_progress > 0.001
	modulate.a = minimum_alpha * safe_progress
	scale = Vector2.ONE


func finish_intro() -> void:
	_intro_active = false
	visible = true
	modulate.a = minimum_alpha
	scale = Vector2.ONE


func is_enter_feedback_active() -> bool:
	return _enter_feedback_active


func _on_title_flow_phase_changed(phase: float) -> void:
	if _enter_feedback_active or _intro_active:
		return
	modulate.a = _alpha_for_title_phase(phase)


func _alpha_for_title_phase(phase: float) -> float:
	if _title_flow_period_seconds <= 0.0:
		return minimum_alpha

	var cycle_seconds := (
		fposmod(phase, 1.0)
		* _title_flow_period_seconds)
	var peak_seconds := minf(
		_title_flow_end_seconds + title_peak_delay_seconds,
		_title_flow_period_seconds - 0.001)
	if cycle_seconds <= _title_flow_end_seconds:
		return minimum_alpha
	if cycle_seconds <= peak_seconds:
		var rise_progress := inverse_lerp(
			_title_flow_end_seconds,
			peak_seconds,
			cycle_seconds)
		return lerpf(
			minimum_alpha,
			1.0,
			smoothstep(0.0, 1.0, rise_progress))

	var settle_progress := inverse_lerp(
		peak_seconds,
		_title_flow_period_seconds,
		cycle_seconds)
	return lerpf(
		1.0,
		minimum_alpha,
		smoothstep(0.0, 1.0, settle_progress))


func _start_fade_loop() -> void:
	modulate.a = minimum_alpha
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_loops()
	_fade_tween.tween_property(
		self,
		"modulate:a",
		1.0,
		fade_duration,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade_tween.tween_property(
		self,
		"modulate:a",
		minimum_alpha,
		fade_duration,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
