class_name Scene4LeafSpiritSwarm
extends Node2D

signal swarm_started(spirit_count: int)
signal swarm_finished

const FRAME_WIDTH := 16
const FRAME_HEIGHT := 14
const FRAME_COUNT := 4
const POOL_SIZE := 24
const FLAP_FPS := 5.4

const OUTLINE_COLOR := Color("#173530")
const BODY_SHADOW_COLOR := Color("#789d9b")
const BODY_COLOR := Color("#b8d3cd")
const BODY_LIGHT_COLOR := Color("#d7e4db")
const WING_SHADOW_COLOR := Color("#5f9180")
const WING_COLOR := Color("#8eb7a0")
const EYE_COLOR := Color("#b9dff2")

@export_group("Achievement swarm")
@export_range(18, POOL_SIZE, 1) var spirit_count_min := 18
@export_range(18, POOL_SIZE, 1) var spirit_count_max := 24
@export_range(2.0, 8.0, 0.1) var flight_duration_min := 4.4
@export_range(2.0, 8.0, 0.1) var flight_duration_max := 5.8
@export_range(1.0, 4.0, 0.1) var spirit_scale_min := 1.8
@export_range(1.0, 4.0, 0.1) var spirit_scale_max := 2.7
@export var spirit_tint := Color(0.9, 0.98, 1.0, 0.96)
@export var seed_offset := 404

@export_group("Ambient schedule")
@export var auto_ambient := true
@export_range(0.0, 60.0, 0.1) var initial_delay_sec := 8.0
@export_range(10.0, 60.0, 0.5) var interval_min_sec := 22.0
@export_range(10.0, 60.0, 0.5) var interval_max_sec := 38.0
@export_range(1, 5, 1) var ambient_spirit_count_min := 2
@export_range(1, 5, 1) var ambient_spirit_count_max := 3
@export_range(1.0, 8.0, 0.1) var ambient_flight_duration_min := 3.4
@export_range(1.0, 8.0, 0.1) var ambient_flight_duration_max := 4.5
@export_range(1.0, 5.0, 0.1) var ambient_spirit_scale_min := 2.3
@export_range(1.0, 5.0, 0.1) var ambient_spirit_scale_max := 2.9

static var _shared_atlas: ImageTexture

var _rng := RandomNumberGenerator.new()
var _pool: Array[Sprite2D] = []
var _active_spirits: Array[Dictionary] = []
var _ambient_timer: Timer
var _active_swarm_kind := &""


func _ready() -> void:
	_rng.seed = hash("%s:%d" % [get_path(), seed_offset])
	_create_pool()
	_ambient_timer = Timer.new()
	_ambient_timer.name = "AmbientTimer"
	_ambient_timer.one_shot = true
	_ambient_timer.timeout.connect(_on_ambient_timer_timeout)
	add_child(_ambient_timer)
	set_process(false)
	if auto_ambient:
		_ambient_timer.start(maxf(initial_delay_sec, 0.05))


func _process(delta: float) -> void:
	for active_index: int in range(_active_spirits.size() - 1, -1, -1):
		var state: Dictionary = _active_spirits[active_index]
		state["elapsed"] = float(state["elapsed"]) + delta
		var elapsed := float(state["elapsed"]) - float(state["delay"])
		var sprite := state["sprite"] as Sprite2D
		if elapsed < 0.0:
			sprite.visible = false
			_active_spirits[active_index] = state
			continue

		sprite.visible = true
		var duration := float(state["duration"])
		var linear_t := clampf(elapsed / duration, 0.0, 1.0)
		var flight_t := _flight_progress(linear_t)
		var start := state["start"] as Vector2
		var control_a := state["control_a"] as Vector2
		var control_b := state["control_b"] as Vector2
		var destination := state["destination"] as Vector2
		var point := _cubic_bezier(
				start, control_a, control_b, destination, flight_t)
		var bob := sin(
				linear_t * TAU * 2.0 + float(state["bob_phase"])) * 4.0
		sprite.position = (point + Vector2(0.0, bob)).round()

		var tangent := _cubic_bezier_tangent(
				start, control_a, control_b, destination, flight_t)
		var direction := int(state["direction"])
		sprite.flip_h = direction < 0
		sprite.rotation = clampf(
				atan2(tangent.y, absf(tangent.x)) * 0.26 * direction,
				-0.16,
				0.16)
		sprite.frame = int(floor(
				elapsed * FLAP_FPS + float(state["frame_phase"])
		)) % FRAME_COUNT

		var fade_in := smoothstep(0.0, 0.09, linear_t)
		var fade_out := 1.0 - smoothstep(0.84, 1.0, linear_t)
		var color := state["color"] as Color
		color.a *= minf(fade_in, fade_out)
		sprite.modulate = color
		_active_spirits[active_index] = state

		if linear_t >= 1.0:
			_release_spirit(active_index)

	if _active_spirits.is_empty():
		set_process(false)
		_active_swarm_kind = &""
		swarm_finished.emit()
		_schedule_next_ambient()


func trigger_achievement_swarm() -> bool:
	_ambient_timer.stop()
	_clear_active_spirits()
	var count := _rng.randi_range(
			mini(spirit_count_min, spirit_count_max),
			maxi(spirit_count_min, spirit_count_max))
	count = mini(count, _pool.size())
	for spirit_index: int in count:
		var direction := 1 if spirit_index % 2 == 0 else -1
		_activate_spirit(spirit_index, count, direction)
	_active_swarm_kind = &"achievement"
	set_process(true)
	swarm_started.emit(count)
	return true


func trigger_ambient_swarm() -> bool:
	if not _active_spirits.is_empty():
		return false
	_ambient_timer.stop()
	var count := _rng.randi_range(
			mini(ambient_spirit_count_min, ambient_spirit_count_max),
			maxi(ambient_spirit_count_min, ambient_spirit_count_max))
	count = mini(count, _pool.size())
	var direction := 1 if _rng.randf() < 0.5 else -1
	for spirit_index: int in count:
		_activate_spirit(spirit_index, count, direction, true)
	_active_swarm_kind = &"ambient"
	set_process(true)
	swarm_started.emit(count)
	return true


func get_active_spirit_count() -> int:
	return _active_spirits.size()


func get_visible_spirit_count() -> int:
	var count := 0
	for sprite: Sprite2D in _pool:
		if sprite.visible:
			count += 1
	return count


func get_active_swarm_kind() -> StringName:
	return _active_swarm_kind


func is_ambient_timer_running() -> bool:
	return _ambient_timer != null and not _ambient_timer.is_stopped()


func get_pool_size() -> int:
	return _pool.size()


func _on_ambient_timer_timeout() -> void:
	trigger_ambient_swarm()


func _schedule_next_ambient() -> void:
	if not auto_ambient or _ambient_timer == null:
		return
	_ambient_timer.start(_rng.randf_range(
			minf(interval_min_sec, interval_max_sec),
			maxf(interval_min_sec, interval_max_sec)))


func _create_pool() -> void:
	if _shared_atlas == null:
		_shared_atlas = _create_atlas()
	for spirit_index: int in POOL_SIZE:
		var sprite := Sprite2D.new()
		sprite.name = "AchievementLeafSpirit%d" % (spirit_index + 1)
		sprite.texture = _shared_atlas
		sprite.hframes = FRAME_COUNT
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = true
		sprite.visible = false
		add_child(sprite)
		_pool.append(sprite)


func _activate_spirit(
		spirit_index: int,
		spirit_count: int,
		direction: int,
		ambient := false
) -> void:
	var sprite := _pool[spirit_index]
	if ambient:
		_activate_ambient_spirit(
				sprite, spirit_index, spirit_count, direction)
		return
	var lane := spirit_index % 6
	var start_x := _rng.randf_range(70.0, 390.0)
	var end_x := _rng.randf_range(1240.0, 1850.0)
	if direction < 0:
		start_x = 1920.0 - start_x
		end_x = 1920.0 - end_x
	var start := Vector2(
			start_x,
			_rng.randf_range(700.0, 890.0) + float(lane) * 18.0)
	var destination := Vector2(
			end_x,
			_rng.randf_range(150.0, 500.0))
	var control_a := start + Vector2(
			float(direction) * _rng.randf_range(250.0, 520.0),
			-_rng.randf_range(170.0, 360.0))
	var control_b := destination + Vector2(
			-float(direction) * _rng.randf_range(180.0, 420.0),
			_rng.randf_range(20.0, 170.0))
	var spirit_scale := _rng.randf_range(
			minf(spirit_scale_min, spirit_scale_max),
			maxf(spirit_scale_min, spirit_scale_max))
	sprite.scale = Vector2.ONE * spirit_scale
	sprite.position = start.round()
	sprite.frame = spirit_index % FRAME_COUNT
	sprite.visible = false

	var color := spirit_tint
	var value_variation := _rng.randf_range(0.9, 1.04)
	color.r *= value_variation
	color.g *= value_variation
	color.b *= value_variation
	_active_spirits.append({
		"sprite": sprite,
		"elapsed": 0.0,
		"delay": float(spirit_index) * _rng.randf_range(0.055, 0.095),
		"duration": _rng.randf_range(
				minf(flight_duration_min, flight_duration_max),
				maxf(flight_duration_min, flight_duration_max)),
		"start": start,
		"control_a": control_a,
		"control_b": control_b,
		"destination": destination,
		"direction": direction,
		"bob_phase": _rng.randf_range(0.0, TAU),
		"frame_phase": _rng.randf_range(0.0, float(FRAME_COUNT)),
		"color": color,
	})


func _activate_ambient_spirit(
		sprite: Sprite2D,
		spirit_index: int,
		spirit_count: int,
		direction: int
) -> void:
	var centered_index := float(spirit_index) - float(spirit_count - 1) * 0.5
	var start_x := _rng.randf_range(280.0, 410.0)
	var end_x := _rng.randf_range(1490.0, 1620.0)
	if direction < 0:
		start_x = 1920.0 - start_x
		end_x = 1920.0 - end_x
	var start := Vector2(
			start_x,
			_rng.randf_range(670.0, 735.0) + centered_index * 26.0)
	var destination := Vector2(
			end_x,
			_rng.randf_range(365.0, 470.0) + centered_index * 18.0)
	var control_a := start + Vector2(
			float(direction) * _rng.randf_range(310.0, 420.0),
			-_rng.randf_range(190.0, 280.0))
	var control_b := destination + Vector2(
			-float(direction) * _rng.randf_range(260.0, 350.0),
			_rng.randf_range(35.0, 105.0))
	var spirit_scale := _rng.randf_range(
			minf(ambient_spirit_scale_min, ambient_spirit_scale_max),
			maxf(ambient_spirit_scale_min, ambient_spirit_scale_max))
	sprite.scale = Vector2.ONE * spirit_scale
	sprite.position = start.round()
	sprite.flip_h = direction < 0
	sprite.frame = _rng.randi_range(0, FRAME_COUNT - 1)
	sprite.visible = false

	var color := spirit_tint
	var value_variation := _rng.randf_range(0.92, 1.03)
	color.r *= value_variation
	color.g *= value_variation
	color.b *= value_variation
	_active_spirits.append({
		"sprite": sprite,
		"elapsed": 0.0,
		"delay": float(spirit_index) * _rng.randf_range(0.18, 0.27),
		"duration": _rng.randf_range(
				minf(ambient_flight_duration_min, ambient_flight_duration_max),
				maxf(ambient_flight_duration_min, ambient_flight_duration_max)),
		"start": start,
		"control_a": control_a,
		"control_b": control_b,
		"destination": destination,
		"direction": direction,
		"bob_phase": _rng.randf_range(0.0, TAU),
		"frame_phase": _rng.randf_range(0.0, float(FRAME_COUNT)),
		"color": color,
	})


func _release_spirit(active_index: int) -> void:
	var state: Dictionary = _active_spirits[active_index]
	var sprite := state["sprite"] as Sprite2D
	sprite.visible = false
	sprite.rotation = 0.0
	_active_spirits.remove_at(active_index)


func _clear_active_spirits() -> void:
	for state: Dictionary in _active_spirits:
		var sprite := state["sprite"] as Sprite2D
		sprite.visible = false
		sprite.rotation = 0.0
	_active_spirits.clear()
	_active_swarm_kind = &""


func _flight_progress(linear_t: float) -> float:
	if linear_t < 0.34:
		return smoothstep(0.0, 0.34, linear_t) * 0.39
	if linear_t < 0.5:
		return lerpf(0.39, 0.45, smoothstep(0.34, 0.5, linear_t))
	return lerpf(0.45, 1.0, smoothstep(0.5, 1.0, linear_t))


func _cubic_bezier(
		start: Vector2,
		control_a: Vector2,
		control_b: Vector2,
		destination: Vector2,
		t: float
) -> Vector2:
	var inverse_t := 1.0 - t
	return (
			inverse_t * inverse_t * inverse_t * start
			+ 3.0 * inverse_t * inverse_t * t * control_a
			+ 3.0 * inverse_t * t * t * control_b
			+ t * t * t * destination
	)


func _cubic_bezier_tangent(
		start: Vector2,
		control_a: Vector2,
		control_b: Vector2,
		destination: Vector2,
		t: float
) -> Vector2:
	var inverse_t := 1.0 - t
	return (
			3.0 * inverse_t * inverse_t * (control_a - start)
			+ 6.0 * inverse_t * t * (control_b - control_a)
			+ 3.0 * t * t * (destination - control_b)
	)


static func _create_atlas() -> ImageTexture:
	var image := Image.create(
			FRAME_WIDTH * FRAME_COUNT,
			FRAME_HEIGHT,
			false,
			Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for frame_index: int in FRAME_COUNT:
		_draw_spirit_frame(image, frame_index)
	return ImageTexture.create_from_image(image)


static func _draw_spirit_frame(image: Image, frame_index: int) -> void:
	var origin_x := frame_index * FRAME_WIDTH
	var left_tips: Array[Vector2i] = [
		Vector2i(1, 4), Vector2i(2, 1), Vector2i(0, 5), Vector2i(2, 9),
	]
	var right_tips: Array[Vector2i] = [
		Vector2i(14, 4), Vector2i(13, 1), Vector2i(15, 5), Vector2i(13, 9),
	]
	var left_tip := left_tips[frame_index]
	var right_tip := right_tips[frame_index]
	_fill_triangle(
			image,
			Vector2i(origin_x + 6, 5),
			Vector2i(origin_x + 5, 9),
			Vector2i(origin_x + left_tip.x, left_tip.y),
			OUTLINE_COLOR)
	_fill_triangle(
			image,
			Vector2i(origin_x + 6, 6),
			Vector2i(origin_x + 5, 8),
			Vector2i(origin_x + left_tip.x + 1, left_tip.y),
			WING_COLOR)
	_fill_triangle(
			image,
			Vector2i(origin_x + 9, 5),
			Vector2i(origin_x + 10, 9),
			Vector2i(origin_x + right_tip.x, right_tip.y),
			OUTLINE_COLOR)
	_fill_triangle(
			image,
			Vector2i(origin_x + 9, 6),
			Vector2i(origin_x + 10, 8),
			Vector2i(origin_x + right_tip.x - 1, right_tip.y),
			WING_SHADOW_COLOR)

	for y: int in range(2, 13):
		for x: int in range(3, 13):
			var normalized := Vector2(
					(float(x) - 7.5) / 4.7,
					(float(y) - 7.0) / 5.4)
			var distance := normalized.length_squared()
			if distance <= 1.0:
				image.set_pixel(origin_x + x, y, OUTLINE_COLOR)
			if distance <= 0.69:
				image.set_pixel(origin_x + x, y, BODY_SHADOW_COLOR)
			if distance <= 0.5:
				image.set_pixel(origin_x + x, y, BODY_COLOR)
	image.set_pixel(origin_x + 6, 3, BODY_LIGHT_COLOR)
	image.set_pixel(origin_x + 7, 3, BODY_LIGHT_COLOR)
	image.set_pixel(origin_x + 6, 4, BODY_LIGHT_COLOR)
	image.set_pixel(origin_x + 7, 6, EYE_COLOR)
	image.set_pixel(origin_x + 10, 6, EYE_COLOR)
	image.set_pixel(origin_x + 8, 9, OUTLINE_COLOR)
	image.set_pixel(origin_x + 9, 9, OUTLINE_COLOR)
	image.set_pixel(origin_x + 7, 12, OUTLINE_COLOR)
	image.set_pixel(origin_x + 8, 13, OUTLINE_COLOR)
	image.set_pixel(origin_x + 9, 12, OUTLINE_COLOR)


static func _fill_triangle(
		image: Image,
		point_a: Vector2i,
		point_b: Vector2i,
		point_c: Vector2i,
		color: Color
) -> void:
	var min_x := mini(point_a.x, mini(point_b.x, point_c.x))
	var max_x := maxi(point_a.x, maxi(point_b.x, point_c.x))
	var min_y := mini(point_a.y, mini(point_b.y, point_c.y))
	var max_y := maxi(point_a.y, maxi(point_b.y, point_c.y))
	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			var point := Vector2(float(x) + 0.5, float(y) + 0.5)
			if _point_in_triangle(
					point,
					Vector2(point_a),
					Vector2(point_b),
					Vector2(point_c)):
				image.set_pixel(x, y, color)


static func _point_in_triangle(
		point: Vector2,
		point_a: Vector2,
		point_b: Vector2,
		point_c: Vector2
) -> bool:
	var edge_a := _edge_sign(point, point_a, point_b)
	var edge_b := _edge_sign(point, point_b, point_c)
	var edge_c := _edge_sign(point, point_c, point_a)
	var has_negative := edge_a < 0.0 or edge_b < 0.0 or edge_c < 0.0
	var has_positive := edge_a > 0.0 or edge_b > 0.0 or edge_c > 0.0
	return not (has_negative and has_positive)


static func _edge_sign(
		point: Vector2,
		point_a: Vector2,
		point_b: Vector2
) -> float:
	return (
			(point.x - point_b.x) * (point_a.y - point_b.y)
			- (point_a.x - point_b.x) * (point.y - point_b.y)
	)
