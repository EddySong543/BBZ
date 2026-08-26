class_name Scene7OasisResonance
extends Node2D

## Scene7-only oasis easter egg. The mature water controls remain responsible
## for pointer hit testing and ripples; this passive listener only turns three
## distinct water-zone clicks into an authored left-to-right light relay.

signal zone_registered(zone_index: int)
signal resonance_started()
signal resonance_finished()

class GlowPulse:
	var age: float = 0.0
	var duration: float
	var strength: float

	func _init(pulse_duration: float, pulse_strength: float) -> void:
		duration = pulse_duration
		strength = pulse_strength


class ResonanceParticle:
	var position: Vector2
	var velocity: Vector2
	var age: float = 0.0
	var lifetime: float
	var size: float
	var phase: float
	var color: Color

	func _init(
			start_position: Vector2,
			start_velocity: Vector2,
			particle_lifetime: float,
			particle_size: float,
			particle_phase: float,
			particle_color: Color) -> void:
		position = start_position
		velocity = start_velocity
		lifetime = particle_lifetime
		size = particle_size
		phase = particle_phase
		color = particle_color


@export_range(3.0, 10.0, 0.1) var trigger_window_sec: float = 6.0
@export_range(0.3, 1.2, 0.05) var sequence_interval_sec: float = 0.62
@export_range(0.0, 0.8, 0.05) var sequence_lead_in_sec: float = 0.30
@export_range(1.0, 3.0, 0.1) var final_hold_sec: float = 1.70
@export_range(960.0, 3840.0, 1.0) var scene_width: float = 1920.0
@export var rear_ripple_path: NodePath = NodePath("../RearSpringClickRipple")
@export var front_ripple_path: NodePath = NodePath("../FrontSpringClickRipple")
@export var particle_origins: Array[Vector2] = [
	Vector2(330.0, 650.0),
	Vector2(960.0, 620.0),
	Vector2(1580.0, 650.0),
]

var glow_group_paths: Array[Array] = [
	[
		NodePath("../MidgroundLeftGlowFX"),
		NodePath("../ForegroundLeftGlowFX"),
	],
	[
		NodePath("../MidgroundCenterGlowFX"),
		NodePath("../MidgroundCenterGrassGlowFX"),
	],
	[
		NodePath("../MidgroundRightGlowFX"),
		NodePath("../MidgroundRightGrassGlowFX"),
	],
]

var _rear_ripple: Control
var _front_ripple: Control
var _glow_groups: Array[Array] = []
var _base_modulates: Dictionary[CanvasItem, Color] = {}
var _active_pulses: Dictionary[CanvasItem, GlowPulse] = {}
var _particles: Array[ResonanceParticle] = []
var _registered_zone_mask: int = 0
var _trigger_window_left: float = 0.0
var _resonating: bool = false
var _sequence_age: float = 0.0
var _next_sequence_stage: int = 0
var _final_burst_fired: bool = false
var _resonance_count: int = 0
var _particle_seed: int = 0


func _ready() -> void:
	_rear_ripple = get_node_or_null(rear_ripple_path) as Control
	_front_ripple = get_node_or_null(front_ripple_path) as Control
	_connect_ripple(_rear_ripple)
	_connect_ripple(_front_ripple)
	_resolve_glow_groups()
	set_process(false)


func _connect_ripple(ripple: Control) -> void:
	if ripple == null or not ripple.has_signal(&"effect_spawned"):
		return
	var callback := Callable(self, "_on_water_effect_spawned")
	if not ripple.is_connected(&"effect_spawned", callback):
		ripple.connect(&"effect_spawned", callback)


func _resolve_glow_groups() -> void:
	_glow_groups.clear()
	for path_group: Array in glow_group_paths:
		var node_group: Array[CanvasItem] = []
		for path_value: Variant in path_group:
			var item := get_node_or_null(path_value as NodePath) as CanvasItem
			if item == null:
				continue
			node_group.append(item)
			_base_modulates[item] = item.modulate
		_glow_groups.append(node_group)


func _on_water_effect_spawned(_effect_kind: int, canvas_position: Vector2) -> void:
	if _resonating:
		return
	register_water_click(canvas_position)


func register_water_click(canvas_position: Vector2) -> bool:
	if _resonating or canvas_position.x < 0.0 or canvas_position.x > scene_width:
		return false
	if _trigger_window_left <= 0.0:
		_registered_zone_mask = 0
	var zone_width := scene_width / 3.0
	var zone_index := clampi(int(floor(canvas_position.x / zone_width)), 0, 2)
	var zone_bit := 1 << zone_index
	if (_registered_zone_mask & zone_bit) != 0:
		return false

	_registered_zone_mask |= zone_bit
	_trigger_window_left = trigger_window_sec
	_pulse_group(zone_index, 0.82, 1.05)
	_spawn_particles(zone_index, 6, 0.82)
	zone_registered.emit(zone_index)
	set_process(true)
	if _registered_zone_mask == 0b111:
		_start_resonance()
	return true


func registered_zone_count() -> int:
	var count := 0
	for zone_index: int in 3:
		if (_registered_zone_mask & (1 << zone_index)) != 0:
			count += 1
	return count


func resonance_count() -> int:
	return _resonance_count


func is_resonating() -> bool:
	return _resonating


func active_pulse_count() -> int:
	return _active_pulses.size()


func particle_count() -> int:
	return _particles.size()


func _start_resonance() -> void:
	_resonating = true
	_sequence_age = 0.0
	_next_sequence_stage = 0
	_final_burst_fired = false
	_resonance_count += 1
	resonance_started.emit()


func _process(delta: float) -> void:
	if not _resonating and _trigger_window_left > 0.0:
		_trigger_window_left = maxf(0.0, _trigger_window_left - delta)
		if _trigger_window_left <= 0.0:
			_registered_zone_mask = 0

	if _resonating:
		_update_resonance_sequence(delta)
	_update_glow_pulses(delta)
	_update_particles(delta)

	var needs_process := _resonating or _trigger_window_left > 0.0 \
			or not _active_pulses.is_empty() or not _particles.is_empty()
	set_process(needs_process)


func _update_resonance_sequence(delta: float) -> void:
	_sequence_age += delta
	while _next_sequence_stage < 3:
		var stage_time := sequence_lead_in_sec \
				+ float(_next_sequence_stage) * sequence_interval_sec
		if _sequence_age < stage_time:
			break
		_fire_sequence_stage(_next_sequence_stage)
		_next_sequence_stage += 1

	var final_time := sequence_lead_in_sec + 3.0 * sequence_interval_sec
	if not _final_burst_fired and _sequence_age >= final_time:
		_fire_final_burst()
		_final_burst_fired = true
	if _sequence_age >= final_time + final_hold_sec:
		_finish_resonance()


func _fire_sequence_stage(zone_index: int) -> void:
	_pulse_group(zone_index, 1.42, 1.48)
	_spawn_particles(zone_index, 12, 1.18)
	var zone_x := particle_origins[zone_index].x
	_spawn_scripted_ripple(_rear_ripple, Vector2(zone_x, 712.0))


func _fire_final_burst() -> void:
	for zone_index: int in 3:
		_pulse_group(zone_index, 1.22, 1.55)
		_spawn_particles(zone_index, 10, 1.30)
	_spawn_scripted_ripple(_rear_ripple, Vector2(scene_width * 0.5, 712.0))
	_spawn_scripted_ripple(_front_ripple, Vector2(scene_width * 0.5, 940.0))


func _finish_resonance() -> void:
	_resonating = false
	_registered_zone_mask = 0
	_trigger_window_left = 0.0
	resonance_finished.emit()


func _spawn_scripted_ripple(ripple: Control, canvas_position: Vector2) -> void:
	if ripple != null and ripple.has_method("try_spawn_at_canvas_position"):
		ripple.call("try_spawn_at_canvas_position", canvas_position)


func _pulse_group(zone_index: int, strength: float, duration: float) -> void:
	if zone_index < 0 or zone_index >= _glow_groups.size():
		return
	for item_value: Variant in _glow_groups[zone_index]:
		var item := item_value as CanvasItem
		if item == null:
			continue
		_active_pulses[item] = GlowPulse.new(duration, strength)


func _update_glow_pulses(delta: float) -> void:
	var finished: Array[CanvasItem] = []
	for item: CanvasItem in _active_pulses.keys():
		if not is_instance_valid(item):
			finished.append(item)
			continue
		var pulse: GlowPulse = _active_pulses[item]
		pulse.age += delta
		var envelope := _pulse_envelope(pulse.age, pulse.duration)
		var boost := pulse.strength * envelope
		var boost_color := Color(
				1.0 + boost * 0.22,
				1.0 + boost * 0.58,
				1.0 + boost * 0.34,
				1.0)
		item.modulate = _base_modulates.get(item, Color.WHITE) * boost_color
		if pulse.age >= pulse.duration:
			finished.append(item)
	for item: CanvasItem in finished:
		if is_instance_valid(item):
			item.modulate = _base_modulates.get(item, Color.WHITE)
		_active_pulses.erase(item)


func _pulse_envelope(age: float, duration: float) -> float:
	var rise_end := minf(0.18, duration * 0.25)
	var hold_end := minf(rise_end + 0.44, duration * 0.62)
	if age < rise_end:
		return smoothstep(0.0, rise_end, age)
	if age < hold_end:
		return 1.0
	return 1.0 - smoothstep(hold_end, duration, age)


func _spawn_particles(zone_index: int, amount: int, energy: float) -> void:
	if zone_index < 0 or zone_index >= particle_origins.size():
		return
	var origin := particle_origins[zone_index]
	for particle_index: int in amount:
		_particle_seed += 1
		var first := _hash(float(_particle_seed), float(particle_index) + 3.1)
		var second := _hash(float(_particle_seed), float(particle_index) + 17.7)
		var third := _hash(float(_particle_seed), float(particle_index) + 41.3)
		var start := origin + Vector2(
				lerpf(-74.0, 74.0, first),
				lerpf(-14.0, 22.0, second))
		var velocity := Vector2(
				lerpf(-24.0, 24.0, second) * energy,
				-lerpf(34.0, 62.0, third) * energy)
		var particle_color := Color(0.42, 1.0, 0.76, 1.0)
		if third > 0.86:
			particle_color = Color(0.96, 0.78, 0.48, 1.0)
		_particles.append(ResonanceParticle.new(
				start,
				velocity,
				lerpf(1.45, 2.15, first),
				6.0 if second > 0.68 else 4.0,
				third * TAU,
				particle_color))
	queue_redraw()


func _update_particles(delta: float) -> void:
	for particle: ResonanceParticle in _particles:
		particle.age += delta
		particle.position += particle.velocity * delta
		particle.position.x += sin(particle.phase + particle.age * 3.2) * delta * 8.0
	for index: int in range(_particles.size() - 1, -1, -1):
		if _particles[index].age >= _particles[index].lifetime:
			_particles.remove_at(index)
	if not _particles.is_empty():
		queue_redraw()


func _draw() -> void:
	for particle: ResonanceParticle in _particles:
		var fade_in := clampf(particle.age / 0.14, 0.0, 1.0)
		var fade_out := clampf(
				(particle.lifetime - particle.age) / 0.42, 0.0, 1.0)
		var alpha := fade_in * fade_out
		var snapped := (particle.position / 2.0).round() * 2.0
		var halo_color := particle.color
		halo_color.a = alpha * 0.20
		var core_color := particle.color
		core_color.a = alpha * 0.95
		draw_rect(Rect2(
				snapped - Vector2.ONE * particle.size,
				Vector2.ONE * particle.size * 2.0), halo_color)
		draw_rect(Rect2(
				snapped - Vector2.ONE * particle.size * 0.5,
				Vector2.ONE * particle.size), core_color)


func _exit_tree() -> void:
	for item: CanvasItem in _base_modulates:
		if is_instance_valid(item):
			item.modulate = _base_modulates[item]


func _hash(seed: float, salt: float) -> float:
	return fposmod(sin(seed * 12.9898 + salt * 78.233) * 43758.5453, 1.0)
