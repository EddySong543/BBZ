class_name Scene3FlyingFishSchool
extends Node2D

signal school_started(fish_count: int)
signal school_finished

const FRAME_WIDTH := 24
const FRAME_HEIGHT := 16
const FRAME_COUNT := 4
const POOL_SIZE := 12
const FLAP_FPS := 6.0

const OUTLINE_COLOR := Color("#14292f")
const BODY_COLOR := Color("#587c80")
const BODY_LIGHT_COLOR := Color("#8fa9a5")
const DAWN_EDGE_COLOR := Color("#e4bd83")
const EYE_COLOR := Color("#fff0bd")
const WING_OUTLINE_COLOR := Color("#27464b")
const WING_COLOR := Color("#8fb5b2")
const WING_LIGHT_COLOR := Color("#d7dfcf")

@export_group("Timing")
@export var auto_start := true
@export_range(0.5, 30.0, 0.1) var initial_delay_sec := 6.0
@export_range(8.0, 60.0, 0.5) var interval_min_sec := 18.0
@export_range(8.0, 60.0, 0.5) var interval_max_sec := 30.0

@export_group("School")
@export_range(1, POOL_SIZE, 1) var fish_count_min := 4
@export_range(1, POOL_SIZE, 1) var fish_count_max := 7
@export_range(0.0, 1920.0, 1.0) var spawn_x_min := 400.0
@export_range(0.0, 1920.0, 1.0) var spawn_x_max := 1520.0
@export_range(0.0, 1920.0, 1.0) var avoid_center_x := 960.0
@export_range(0.0, 600.0, 1.0) var avoid_center_half_width := 190.0
@export_range(0.0, 1080.0, 1.0) var surface_y_min := 790.0
@export_range(0.0, 1080.0, 1.0) var surface_y_max := 840.0

@export_group("Leap")
@export_range(40.0, 320.0, 1.0) var arc_height_min := 90.0
@export_range(40.0, 320.0, 1.0) var arc_height_max := 150.0
@export_range(80.0, 520.0, 1.0) var travel_x_min := 170.0
@export_range(80.0, 520.0, 1.0) var travel_x_max := 290.0
@export_range(0.8, 4.0, 0.05) var leap_duration_min := 1.5
@export_range(0.8, 4.0, 0.05) var leap_duration_max := 2.2
@export_range(0.5, 4.0, 0.05) var fish_scale_min := 1.45
@export_range(0.5, 4.0, 0.05) var fish_scale_max := 1.95

@export_group("Palette")
@export var fish_tint := Color(0.62, 0.76, 0.76, 0.8)
@export var cloud_puff_color := Color(0.76, 0.84, 0.81, 0.32)
@export var seed_offset := 0

static var _shared_atlas: ImageTexture

var _rng := RandomNumberGenerator.new()
var _event_timer: Timer
var _pool: Array[Sprite2D] = []
var _active_fish: Array[Dictionary] = []
var _cloud_puffs: Array[Dictionary] = []
var _event_active := false


static func shared_fish_atlas() -> ImageTexture:
	return _fish_atlas()


func _ready() -> void:
	_rng.seed = int(Time.get_ticks_usec()) + seed_offset
	_create_pool()
	_event_timer = Timer.new()
	_event_timer.one_shot = true
	_event_timer.timeout.connect(_on_event_timer_timeout)
	add_child(_event_timer)
	set_process(false)
	if auto_start:
		_event_timer.start(maxf(initial_delay_sec, 0.1))


func trigger_school(direction_override: int = 0) -> bool:
	if _event_active:
		return false

	var count := clampi(
			_rng.randi_range(fish_count_min, fish_count_max),
			1,
			POOL_SIZE)
	var direction := clampi(direction_override, -1, 1)
	if direction == 0:
		direction = -1 if _rng.randi_range(0, 1) == 0 else 1
	var base_travel := _rng.randf_range(travel_x_min, travel_x_max)
	var center_x := _choose_school_center(base_travel)

	_event_timer.stop()
	_event_active = true
	for index in count:
		_prepare_fish(index, count, direction, center_x, base_travel)
	set_process(true)
	school_started.emit(count)
	return true


func get_active_fish_count() -> int:
	return _active_fish.size()


func get_pool_size() -> int:
	return _pool.size()


func _on_event_timer_timeout() -> void:
	trigger_school()


func _process(delta: float) -> void:
	for index in range(_active_fish.size() - 1, -1, -1):
		var state: Dictionary = _active_fish[index]
		var elapsed := float(state["elapsed"]) + delta
		state["elapsed"] = elapsed
		var sprite := state["sprite"] as Sprite2D
		if elapsed < 0.0:
			_active_fish[index] = state
			continue

		if not bool(state["entry_puff_done"]):
			sprite.visible = true
			if bool(state["puff_enabled"]):
				_add_cloud_puff(state["start"] as Vector2)
			state["entry_puff_done"] = true

		var duration := float(state["duration"])
		var t := clampf(elapsed / duration, 0.0, 1.0)
		_update_fish_sprite(sprite, state, t, elapsed)
		if t >= 0.84 and not bool(state["exit_puff_done"]):
			if bool(state["puff_enabled"]):
				_add_cloud_puff(state["end"] as Vector2)
			state["exit_puff_done"] = true

		if t >= 1.0:
			_release_fish(sprite)
			_active_fish.remove_at(index)
		else:
			_active_fish[index] = state

	_update_cloud_puffs(delta)
	if _event_active and _active_fish.is_empty():
		_event_active = false
		school_finished.emit()
		if auto_start:
			_event_timer.start(_rng.randf_range(
					interval_min_sec,
					maxf(interval_min_sec, interval_max_sec)))
	if _active_fish.is_empty() and _cloud_puffs.is_empty():
		set_process(false)


func _prepare_fish(
		index: int,
		count: int,
		direction: int,
		center_x: float,
		base_travel: float) -> void:
	var sprite := _pool[index]
	var line_offset := (
			float(index) - (float(count) - 1.0) * 0.5) * 27.0
	var travel := clampf(
			base_travel + _rng.randf_range(-28.0, 28.0),
			travel_x_min,
			travel_x_max)
	var start_x := center_x - float(direction) * travel * 0.5
	start_x += line_offset * float(direction) + _rng.randf_range(-22.0, 22.0)
	var surface_y := _rng.randf_range(surface_y_min, surface_y_max)
	var start := Vector2(start_x, surface_y + _rng.randf_range(-8.0, 8.0))
	var end := Vector2(
			start.x + float(direction) * travel,
			surface_y + _rng.randf_range(-10.0, 10.0))
	var delay := float(index) * _rng.randf_range(0.11, 0.18)
	var tint_variation := _rng.randf_range(0.92, 1.08)

	sprite.visible = false
	sprite.flip_h = direction < 0
	_active_fish.append({
		"sprite": sprite,
		"elapsed": -delay,
		"duration": _rng.randf_range(
				leap_duration_min,
				maxf(leap_duration_min, leap_duration_max)),
		"start": start,
		"end": end,
		"arc_height": _rng.randf_range(
				arc_height_min,
				maxf(arc_height_min, arc_height_max)),
		"scale": _rng.randf_range(
				fish_scale_min,
				maxf(fish_scale_min, fish_scale_max)),
		"flap_phase": _rng.randf_range(0.0, float(FRAME_COUNT)),
		"tint_variation": tint_variation,
		"direction": direction,
		"puff_enabled": index % 2 == 0,
		"entry_puff_done": false,
		"exit_puff_done": false,
	})


func _update_fish_sprite(
		sprite: Sprite2D,
		state: Dictionary,
		t: float,
		elapsed: float) -> void:
	var start := state["start"] as Vector2
	var end := state["end"] as Vector2
	var arc_height := float(state["arc_height"])
	var arc_offset := 4.0 * arc_height * t * (1.0 - t)
	sprite.position = start.lerp(end, t) - Vector2(0.0, arc_offset)

	var horizontal_speed := absf(end.x - start.x)
	var vertical_speed := (
			end.y - start.y
			- 4.0 * arc_height * (1.0 - 2.0 * t))
	var direction := int(state["direction"])
	sprite.rotation = atan2(vertical_speed, horizontal_speed) * float(direction)
	var fish_scale := float(state["scale"])
	sprite.scale = Vector2.ONE * fish_scale
	sprite.frame = (
			int(floor(elapsed * FLAP_FPS + float(state["flap_phase"])))
			% FRAME_COUNT)

	var alpha := smoothstep(0.0, 0.12, t) \
			* (1.0 - smoothstep(0.84, 1.0, t))
	var tint_variation := float(state["tint_variation"])
	sprite.modulate = Color(
			fish_tint.r * tint_variation,
			fish_tint.g * tint_variation,
			fish_tint.b * tint_variation,
			fish_tint.a * alpha)


func _choose_school_center(travel: float) -> float:
	var margin := travel * 0.55 + 24.0
	var minimum := spawn_x_min + margin
	var maximum := spawn_x_max - margin
	if minimum >= maximum:
		return (spawn_x_min + spawn_x_max) * 0.5

	var center := _rng.randf_range(minimum, maximum)
	if absf(center - avoid_center_x) < avoid_center_half_width:
		var side := -1.0 if _rng.randi_range(0, 1) == 0 else 1.0
		center = avoid_center_x + side * avoid_center_half_width
	return clampf(center, minimum, maximum)


func _create_pool() -> void:
	var atlas := _fish_atlas()
	for index in POOL_SIZE:
		var sprite := Sprite2D.new()
		sprite.name = "Fish%02d" % index
		sprite.texture = atlas
		sprite.hframes = FRAME_COUNT
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


func _add_cloud_puff(at: Vector2) -> void:
	_cloud_puffs.append({
		"position": at,
		"life": 0.0,
		"duration": _rng.randf_range(0.55, 0.75),
		"scale": _rng.randf_range(0.85, 1.15),
	})
	queue_redraw()


func _update_cloud_puffs(delta: float) -> void:
	for index in range(_cloud_puffs.size() - 1, -1, -1):
		var puff: Dictionary = _cloud_puffs[index]
		puff["life"] = float(puff["life"]) + delta
		if float(puff["life"]) >= float(puff["duration"]):
			_cloud_puffs.remove_at(index)
		else:
			_cloud_puffs[index] = puff
	if not _cloud_puffs.is_empty():
		queue_redraw()


func _draw() -> void:
	for puff in _cloud_puffs:
		var life_ratio := clampf(
				float(puff["life"]) / float(puff["duration"]),
				0.0,
				1.0)
		var alpha := smoothstep(0.0, 0.12, life_ratio) \
				* (1.0 - smoothstep(0.44, 1.0, life_ratio))
		var puff_scale := float(puff["scale"]) * lerpf(
				0.75,
				1.45,
				life_ratio)
		var color := cloud_puff_color
		color.a *= alpha
		var origin := puff["position"] as Vector2
		draw_circle(
				origin + Vector2(-5.0, 0.0) * puff_scale,
				3.0 * puff_scale,
				color,
				true,
				-1.0,
				false)
		draw_circle(
				origin + Vector2(1.0, -2.0) * puff_scale,
				4.0 * puff_scale,
				color,
				true,
				-1.0,
				false)
		draw_circle(
				origin + Vector2(6.0, 1.0) * puff_scale,
				2.5 * puff_scale,
				color,
				true,
				-1.0,
				false)


static func _fish_atlas() -> ImageTexture:
	if _shared_atlas != null:
		return _shared_atlas

	var image := Image.create(
			FRAME_WIDTH * FRAME_COUNT,
			FRAME_HEIGHT,
			false,
			Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for frame in FRAME_COUNT:
		_paint_tail(image, frame)
		_paint_wings(image, frame)
		_paint_body(image, frame)
	_shared_atlas = ImageTexture.create_from_image(image)
	return _shared_atlas


static func _paint_tail(image: Image, frame: int) -> void:
	var frame_x := frame * FRAME_WIDTH
	var bend: float = [0.0, -1.7, 0.0, 1.7][frame]
	for x in range(0, 9):
		var progress := float(x) / 8.0
		var center_y: float = 7.5 + bend * (1.0 - progress)
		var half_height := lerpf(4.6, 1.2, progress)
		for y in FRAME_HEIGHT:
			var distance := absf(float(y) - center_y)
			if distance <= half_height:
				var color := OUTLINE_COLOR
				if distance < half_height - 1.0 and x < 7:
					color = BODY_COLOR
				image.set_pixel(frame_x + x, y, color)


static func _paint_wings(image: Image, frame: int) -> void:
	var frame_x := frame * FRAME_WIDTH
	var upper_tips: Array[Vector2i] = [
		Vector2i(8, 3),
		Vector2i(10, 0),
		Vector2i(7, 5),
		Vector2i(9, 6),
	]
	var lower_tips: Array[Vector2i] = [
		Vector2i(8, 12),
		Vector2i(10, 10),
		Vector2i(7, 11),
		Vector2i(10, 15),
	]
	var upper_tip := upper_tips[frame]
	var lower_tip := lower_tips[frame]
	_paint_triangle(
			image,
			frame_x,
			Vector2i(12, 7),
			upper_tip,
			Vector2i(18, 5),
			WING_OUTLINE_COLOR)
	_paint_triangle(
			image,
			frame_x,
			Vector2i(12, 6),
			upper_tip + Vector2i(1, 1),
			Vector2i(16, 5),
			WING_COLOR)
	_paint_triangle(
			image,
			frame_x,
			Vector2i(12, 8),
			lower_tip,
			Vector2i(18, 10),
			WING_OUTLINE_COLOR)
	_paint_triangle(
			image,
			frame_x,
			Vector2i(12, 9),
			lower_tip + Vector2i(1, -1),
			Vector2i(16, 10),
			WING_COLOR)
	_set_pixel_safe(
			image,
			frame_x + upper_tip.x,
			upper_tip.y,
			WING_LIGHT_COLOR)
	_set_pixel_safe(
			image,
			frame_x + lower_tip.x,
			lower_tip.y,
			DAWN_EDGE_COLOR)


static func _paint_body(image: Image, frame: int) -> void:
	var frame_x := frame * FRAME_WIDTH
	for y in FRAME_HEIGHT:
		for x in range(6, FRAME_WIDTH):
			var dx := (float(x) - 15.0) / 8.2
			var dy := (float(y) - 7.5) / 4.5
			if dx * dx + dy * dy <= 1.0:
				image.set_pixel(frame_x + x, y, OUTLINE_COLOR)

	for y in range(4, 12):
		for x in range(7, 23):
			var dx := (float(x) - 15.0) / 7.1
			var dy := (float(y) - 7.5) / 3.3
			if dx * dx + dy * dy <= 1.0:
				image.set_pixel(frame_x + x, y, BODY_COLOR)

	for x in range(11, 19):
		image.set_pixel(frame_x + x, 5, BODY_LIGHT_COLOR)
	for x in range(10, 20):
		image.set_pixel(frame_x + x, 10, DAWN_EDGE_COLOR)
	image.set_pixel(frame_x + 20, 7, EYE_COLOR)
	image.set_pixel(frame_x + 21, 7, OUTLINE_COLOR)
	image.set_pixel(frame_x + 22, 8, OUTLINE_COLOR)


static func _paint_triangle(
		image: Image,
		frame_x: int,
		a: Vector2i,
		b: Vector2i,
		c: Vector2i,
		color: Color) -> void:
	var minimum_x := maxi(0, mini(a.x, mini(b.x, c.x)))
	var maximum_x := mini(FRAME_WIDTH - 1, maxi(a.x, maxi(b.x, c.x)))
	var minimum_y := maxi(0, mini(a.y, mini(b.y, c.y)))
	var maximum_y := mini(FRAME_HEIGHT - 1, maxi(a.y, maxi(b.y, c.y)))
	for y in range(minimum_y, maximum_y + 1):
		for x in range(minimum_x, maximum_x + 1):
			var point := Vector2(float(x) + 0.5, float(y) + 0.5)
			var edge_ab := _triangle_edge(Vector2(a), Vector2(b), point)
			var edge_bc := _triangle_edge(Vector2(b), Vector2(c), point)
			var edge_ca := _triangle_edge(Vector2(c), Vector2(a), point)
			var has_negative := edge_ab < 0.0 or edge_bc < 0.0 or edge_ca < 0.0
			var has_positive := edge_ab > 0.0 or edge_bc > 0.0 or edge_ca > 0.0
			if not (has_negative and has_positive):
				image.set_pixel(frame_x + x, y, color)


static func _triangle_edge(a: Vector2, b: Vector2, point: Vector2) -> float:
	return (point.x - b.x) * (a.y - b.y) \
			- (a.x - b.x) * (point.y - b.y)


static func _set_pixel_safe(
		image: Image,
		x: int,
		y: int,
		color: Color) -> void:
	if x < 0 or x >= image.get_width() or y < 0 or y >= FRAME_HEIGHT:
		return
	image.set_pixel(x, y, color)
