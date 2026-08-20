class_name Scene3VerticalFishEasterEgg
extends Node2D

signal vertical_school_started(fish_count: int)
signal vertical_school_finished

const FORMATION_OFFSETS: Array[float] = [0.0, -36.0, 34.0]
const FLAP_FPS := 7.0

@export_group("Trigger")
@export_range(1, 12, 1) var minimum_clicks_before_roll := 3
@export_range(0.0, 1.0, 0.01) var trigger_probability := 0.05
@export_range(0.0, 1.0, 0.01) var trigger_delay_sec := 0.07
@export_range(0.0, 12.0, 0.25) var retrigger_cooldown := 6.0

@export_group("School")
@export_range(2, 3, 1) var fish_count_min := 2
@export_range(2, 3, 1) var fish_count_max := 3
@export_range(600.0, 1100.0, 10.0) var surface_y := 846.0
@export_range(-200.0, 100.0, 10.0) var top_y := -80.0
@export_range(0.5, 1.2, 0.01) var flight_duration := 0.78
@export_range(0.02, 0.1, 0.005) var stagger_sec := 0.035
@export var fish_tint := Color(0.76, 0.86, 0.82, 0.96)

var _launch_pending := false
var _launch_delay_left := 0.0
var _launch_origin := Vector2.ZERO
var _valid_clicks_since_launch := 0
var _cooldown_left := 0.0
var _school_running := false
var _pool: Array[Sprite2D] = []
var _active_fish: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = int(Time.get_ticks_usec()) + 1703
	_create_pool()
	set_process(false)


func _on_cloud_disturbed(canvas_position: Vector2) -> void:
	register_cloud_click(canvas_position)


func register_cloud_click(canvas_position: Vector2) -> bool:
	if _launch_pending or not _active_fish.is_empty() or _cooldown_left > 0.0:
		return false
	_valid_clicks_since_launch += 1
	if _valid_clicks_since_launch < minimum_clicks_before_roll:
		return false
	if _rng.randf() >= trigger_probability:
		return false
	_valid_clicks_since_launch = 0
	_cooldown_left = retrigger_cooldown
	_prepare_launch(canvas_position)
	return true


func get_active_fish_count() -> int:
	return _active_fish.size()


func get_pool_size() -> int:
	return _pool.size()


func fish_vertical_travel() -> float:
	return surface_y - top_y


func uses_shared_fish_atlas() -> bool:
	if _pool.is_empty():
		return false
	return _pool[0].texture == Scene3FlyingFishSchool.shared_fish_atlas()


func get_highest_active_fish_y() -> float:
	var highest := INF
	for state in _active_fish:
		var sprite := state["sprite"] as Sprite2D
		if sprite.visible:
			highest = minf(highest, sprite.position.y)
	return highest


func _process(delta: float) -> void:
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	if _launch_pending:
		_launch_delay_left -= delta
		if _launch_delay_left <= 0.0:
			_launch_pending = false
			_launch_school()

	for index in range(_active_fish.size() - 1, -1, -1):
		var state: Dictionary = _active_fish[index]
		var elapsed := float(state["elapsed"]) + delta
		state["elapsed"] = elapsed
		var sprite := state["sprite"] as Sprite2D
		if elapsed < 0.0:
			_active_fish[index] = state
			continue
		var duration := float(state["duration"])
		var phase := clampf(elapsed / maxf(duration, 0.001), 0.0, 1.0)
		_update_fish(sprite, state, phase, elapsed)
		if phase >= 1.0:
			_release_fish(sprite)
			_active_fish.remove_at(index)
		else:
			_active_fish[index] = state

	if _school_running and _active_fish.is_empty():
		_school_running = false
		vertical_school_finished.emit()
	if not _launch_pending and _active_fish.is_empty() and _cooldown_left <= 0.0:
		set_process(false)


func _prepare_launch(canvas_position: Vector2) -> void:
	_launch_origin = get_global_transform_with_canvas().affine_inverse() \
			* canvas_position
	_launch_origin.x = clampf(_launch_origin.x, 280.0, 1640.0)
	_launch_origin.y = surface_y
	_launch_delay_left = trigger_delay_sec
	_launch_pending = trigger_delay_sec > 0.0
	if _launch_pending:
		set_process(true)
	else:
		_launch_school()


func _launch_school() -> void:
	if not _active_fish.is_empty():
		return
	var minimum := mini(fish_count_min, fish_count_max)
	var maximum := maxi(fish_count_min, fish_count_max)
	var count := mini(_rng.randi_range(minimum, maximum), _pool.size())
	for index in count:
		var sprite := _pool[index]
		var formation_offset := FORMATION_OFFSETS[index]
		var start := _launch_origin + Vector2(
				formation_offset,
				absf(formation_offset) * 0.12)
		var end := Vector2(
				start.x + formation_offset * 0.34,
				top_y - float(index) * 14.0)
		var launch_lag := float(index) * stagger_sec
		if index == count - 1:
			launch_lag += 0.055
		var fish_scale := 2.5 if index == 0 else 1.95 + float(index % 2) * 0.15
		_active_fish.append({
			"sprite": sprite,
			"elapsed": -launch_lag,
			"duration": flight_duration + (0.08 if index == count - 1 else 0.0),
			"start": start,
			"end": end,
			"scale": fish_scale,
			"sway": 7.0 + float(index % 3) * 4.0,
			"phase": float(index) * 1.37,
		})
	set_process(true)
	_school_running = true
	vertical_school_started.emit(count)


func _update_fish(
		sprite: Sprite2D,
		state: Dictionary,
		phase: float,
		elapsed: float) -> void:
	var start := state["start"] as Vector2
	var end := state["end"] as Vector2
	var ascent := 1.0 - pow(1.0 - phase, 1.55)
	var position := start.lerp(end, ascent)
	position.x += sin(phase * PI * 1.15 + float(state["phase"])) \
			* float(state["sway"]) * sin(phase * PI)
	sprite.position = position.round()
	sprite.rotation = -PI * 0.5 + sin(phase * PI * 1.5 \
			+ float(state["phase"])) * 0.055
	sprite.scale = Vector2.ONE * float(state["scale"])
	sprite.frame = int(floor(elapsed * FLAP_FPS)) % 4
	sprite.visible = true
	var alpha := smoothstep(0.0, 0.07, phase) \
			* (1.0 - smoothstep(0.82, 1.0, phase))
	var depth_tint := lerpf(0.86, 1.04, phase)
	sprite.modulate = Color(
			fish_tint.r * depth_tint,
			fish_tint.g * depth_tint,
			fish_tint.b * depth_tint,
			fish_tint.a * alpha)


func _create_pool() -> void:
	var atlas := Scene3FlyingFishSchool.shared_fish_atlas()
	for index in fish_count_max:
		var sprite := Sprite2D.new()
		sprite.name = "VerticalFish%02d" % index
		sprite.texture = atlas
		sprite.hframes = 4
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = true
		sprite.visible = false
		add_child(sprite)
		_pool.append(sprite)


func _release_fish(sprite: Sprite2D) -> void:
	sprite.visible = false
	sprite.position = Vector2.ZERO
	sprite.rotation = 0.0
	sprite.scale = Vector2.ONE
	sprite.modulate = Color.WHITE
