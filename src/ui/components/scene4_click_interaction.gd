class_name Scene4ClickInteraction
extends Node

signal interaction_triggered(target_name: StringName)
signal achievement_progress_changed(progress: int, required: int)
signal achievement_completed
signal achievement_effect_triggered(trigger_count: int)

const STONE_TARGETS: Array[StringName] = [
	&"RuinStone1",
	&"RuinStone2",
	&"RuinStone3",
	&"RuinStone4",
]
const ACHIEVEMENT_SEQUENCE: Array[StringName] = [
	&"RuinStone4",
	&"RuinStone2",
	&"RuinStone3",
	&"RuinStone1",
]
# Reverse visual draw order: the first opaque target owns the click.
const HIT_PRIORITY: Array[StringName] = [
	&"RuinStone4",
	&"RuinStone3",
	&"RuinStone2",
	&"RuinStone1",
]

@export_group("Relic response")
@export_range(0.02, 0.25, 0.01) var relic_flash_rise_sec := 0.05
@export_range(0.0, 0.3, 0.01) var relic_flash_hold_sec := 0.16
@export_range(0.15, 1.2, 0.01) var relic_flash_fall_sec := 0.72

@export_group("Scene achievement")
@export_range(1.0, 15.0, 0.1) var achievement_window_sec := 8.0
@export_range(10.0, 90.0, 1.0) var achievement_cooldown_sec := 30.0
@export_range(0.02, 3.0, 0.01) var achievement_sync_hold_sec := 1.6
@export_range(0.02, 1.5, 0.01) var achievement_sync_fall_sec := 0.45
@export_range(0.02, 8.0, 0.01) var achievement_glow_hold_sec := 3.4
@export_range(0.02, 1.5, 0.01) var achievement_glow_fall_sec := 0.6
@export var achievement_spirits_path := NodePath("../AchievementLeafSpirits")

@export_group("Hit testing")
@export_range(0.01, 0.8, 0.01) var alpha_hit_threshold := 0.12

var _targets: Dictionary[StringName, TextureRect] = {}
var _source_images: Dictionary[StringName, Image] = {}
var _parameter_tweens: Dictionary[String, Tween] = {}
var _trigger_counts: Dictionary[StringName, int] = {}
var _achievement_timer: Timer
var _achievement_cooldown_timer: Timer
var _achievement_progress := 0
var _achievement_has_completed_once := false
var _achievement_trigger_count := 0


func _ready() -> void:
	_achievement_timer = Timer.new()
	_achievement_timer.name = "AchievementWindowTimer"
	_achievement_timer.one_shot = true
	_achievement_timer.timeout.connect(_reset_achievement_sequence)
	add_child(_achievement_timer)
	_achievement_cooldown_timer = Timer.new()
	_achievement_cooldown_timer.name = "AchievementCooldownTimer"
	_achievement_cooldown_timer.one_shot = true
	add_child(_achievement_cooldown_timer)
	for target_name: StringName in HIT_PRIORITY:
		var target := get_parent().get_node_or_null(NodePath(target_name)) as TextureRect
		if target == null:
			push_warning("Scene4ClickInteraction: missing target %s" % target_name)
			continue
		_targets[target_name] = target
		_trigger_counts[target_name] = 0
		if target.texture != null:
			var source_image := target.texture.get_image()
			if source_image != null and not source_image.is_empty():
				_source_images[target_name] = source_image


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var target_name := get_hit_target_at(mouse_event.position)
	if target_name == &"":
		return
	if trigger_target(target_name):
		get_viewport().set_input_as_handled()


func get_hit_target_at(screen_position: Vector2) -> StringName:
	for target_name: StringName in HIT_PRIORITY:
		if _is_opaque_hit(target_name, screen_position):
			return target_name
	return &""


func trigger_target(target_name: StringName) -> bool:
	if target_name not in STONE_TARGETS or not _targets.has(target_name):
		return false
	_trigger_counts[target_name] = _trigger_counts.get(target_name, 0) + 1
	_trigger_relic_flash(target_name)
	_track_achievement_click(target_name)
	interaction_triggered.emit(target_name)
	return true


func get_trigger_count(target_name: StringName) -> int:
	return _trigger_counts.get(target_name, 0)


func get_achievement_progress() -> int:
	return _achievement_progress


func is_achievement_completed() -> bool:
	return _achievement_has_completed_once


func is_achievement_on_cooldown() -> bool:
	return (
			_achievement_cooldown_timer != null
			and not _achievement_cooldown_timer.is_stopped()
	)


func get_achievement_trigger_count() -> int:
	return _achievement_trigger_count


func _is_opaque_hit(target_name: StringName, screen_position: Vector2) -> bool:
	var target := _targets.get(target_name) as TextureRect
	var source_image := _source_images.get(target_name) as Image
	if target == null or source_image == null or not target.is_visible_in_tree():
		return false
	if target.size.x <= 0.0 or target.size.y <= 0.0:
		return false
	var local_position := target.get_global_transform_with_canvas() \
			.affine_inverse() * screen_position
	if not Rect2(Vector2.ZERO, target.size).has_point(local_position):
		return false
	var uv := local_position / target.size
	if target.flip_h:
		uv.x = 1.0 - uv.x
	if target.flip_v:
		uv.y = 1.0 - uv.y
	var pixel := Vector2i(
			clampi(int(floor(uv.x * source_image.get_width())),
					0, source_image.get_width() - 1),
			clampi(int(floor(uv.y * source_image.get_height())),
					0, source_image.get_height() - 1))
	return source_image.get_pixelv(pixel).a >= alpha_hit_threshold


func _trigger_relic_flash(target_name: StringName) -> void:
	var material := _target_material(target_name)
	if material == null:
		return
	var tween_key := "%s:flash" % target_name
	_kill_parameter_tween(tween_key)
	material.set_shader_parameter("interaction_flash", 0.0)
	var tween := create_tween()
	_parameter_tweens[tween_key] = tween
	tween.tween_method(
			func(value: float) -> void:
				material.set_shader_parameter("interaction_flash", value),
			0.0,
			1.0,
			relic_flash_rise_sec
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if relic_flash_hold_sec > 0.0:
		tween.tween_interval(relic_flash_hold_sec)
	tween.tween_method(
			func(value: float) -> void:
				material.set_shader_parameter("interaction_flash", value),
			1.0,
			0.0,
			relic_flash_fall_sec
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _track_achievement_click(target_name: StringName) -> void:
	if is_achievement_on_cooldown():
		return
	if _achievement_progress > 0 and _achievement_timer.is_stopped():
		_reset_achievement_sequence()
	var expected_target := ACHIEVEMENT_SEQUENCE[_achievement_progress]
	if target_name != expected_target:
		_reset_achievement_sequence()
		if target_name == ACHIEVEMENT_SEQUENCE[0]:
			_start_achievement_sequence()
		return
	if _achievement_progress == 0:
		_start_achievement_sequence()
	else:
		_achievement_progress += 1
		achievement_progress_changed.emit(
				_achievement_progress, ACHIEVEMENT_SEQUENCE.size())
	if _achievement_progress >= ACHIEVEMENT_SEQUENCE.size():
		_complete_achievement()


func _start_achievement_sequence() -> void:
	_achievement_progress = 1
	_achievement_timer.start(achievement_window_sec)
	achievement_progress_changed.emit(
			_achievement_progress, ACHIEVEMENT_SEQUENCE.size())


func _reset_achievement_sequence() -> void:
	_achievement_timer.stop()
	if _achievement_progress == 0:
		return
	_achievement_progress = 0
	achievement_progress_changed.emit(0, ACHIEVEMENT_SEQUENCE.size())


func _complete_achievement() -> void:
	_achievement_timer.stop()
	_achievement_progress = 0
	achievement_progress_changed.emit(0, ACHIEVEMENT_SEQUENCE.size())
	_achievement_trigger_count += 1
	_achievement_cooldown_timer.start(achievement_cooldown_sec)
	_set_all_relic_parameter("achievement_glow", 1.0)
	_set_all_relic_parameter("achievement_sync", 1.0)
	_kill_parameter_tween("achievement:sync")
	var sync_tween := create_tween()
	_parameter_tweens["achievement:sync"] = sync_tween
	sync_tween.tween_interval(achievement_sync_hold_sec)
	sync_tween.tween_method(
			_set_achievement_sync_strength,
			1.0,
			0.0,
			achievement_sync_fall_sec
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_kill_parameter_tween("achievement:glow")
	var glow_tween := create_tween()
	_parameter_tweens["achievement:glow"] = glow_tween
	glow_tween.tween_interval(achievement_glow_hold_sec)
	glow_tween.tween_method(
			_set_achievement_glow_strength,
			1.0,
			0.0,
			achievement_glow_fall_sec
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var spirits := get_node_or_null(achievement_spirits_path)
	if spirits != null and spirits.has_method("trigger_achievement_swarm"):
		spirits.call("trigger_achievement_swarm")
	achievement_effect_triggered.emit(_achievement_trigger_count)
	if not _achievement_has_completed_once:
		_achievement_has_completed_once = true
		achievement_completed.emit()


func _set_achievement_sync_strength(value: float) -> void:
	_set_all_relic_parameter("achievement_sync", value)


func _set_achievement_glow_strength(value: float) -> void:
	_set_all_relic_parameter("achievement_glow", value)


func _set_all_relic_parameter(parameter_name: StringName, value: float) -> void:
	for target_name: StringName in STONE_TARGETS:
		var material := _target_material(target_name)
		if material != null:
			material.set_shader_parameter(parameter_name, value)


func _target_material(target_name: StringName) -> ShaderMaterial:
	var target := _targets.get(target_name) as TextureRect
	if target == null:
		return null
	return target.material as ShaderMaterial


func _kill_parameter_tween(tween_key: String) -> void:
	var old_tween := _parameter_tweens.get(tween_key) as Tween
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()
	_parameter_tweens.erase(tween_key)
