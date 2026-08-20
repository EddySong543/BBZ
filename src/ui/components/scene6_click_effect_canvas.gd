class_name Scene6ClickEffectCanvas
extends Control

## Pixel-stable, short-lived click effects for Scene6. The three canvases using
## this component sit at different draw depths, so existing platform and
## foreground art provide real occlusion instead of a screen-space fake.

enum EffectKind {
	NONE,
	FOREGROUND_SPARK,
	MAGMA_BUBBLE,
	MIDGROUND_SPIT,
}


class ClickEffect:
	var kind: int
	var origin: Vector2
	var age: float = 0.0
	var seed: float
	var depth_scale: float

	func _init(
			effect_kind: int,
			effect_origin: Vector2,
			effect_seed: float,
			effect_depth_scale: float
	) -> void:
		kind = effect_kind
		origin = effect_origin
		seed = effect_seed
		depth_scale = effect_depth_scale


@export_range(1, 10, 1) var max_effects: int = 6
@export_range(2.0, 6.0, 1.0) var pixel_size: float = 4.0
@export var spark_core_color: Color = Color(1.0, 0.62, 0.16, 0.96)
@export var spark_hot_color: Color = Color(1.0, 0.30, 0.055, 0.92)
@export var spark_tail_color: Color = Color(0.58, 0.065, 0.018, 0.72)
@export var magma_core_color: Color = Color(1.0, 0.60, 0.16, 0.95)
@export var magma_hot_color: Color = Color(1.0, 0.28, 0.045, 0.92)
@export var magma_body_color: Color = Color(0.62, 0.055, 0.012, 0.88)
@export var magma_shadow_color: Color = Color(0.10, 0.008, 0.018, 0.78)

const SPARK_LIFETIME_SEC := 0.44
const BUBBLE_LIFETIME_SEC := 0.92
const SPIT_LIFETIME_SEC := 0.68

var _effects: Array[ClickEffect] = []
var _seed_counter: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func spawn_effect(
		effect_kind: int,
		local_position: Vector2,
		depth_scale: float = 1.0
) -> bool:
	if effect_kind <= EffectKind.NONE or effect_kind > EffectKind.MIDGROUND_SPIT:
		return false
	_seed_counter += 1
	var seed := float(_seed_counter) * 19.37 \
			+ local_position.x * 0.021 + local_position.y * 0.013
	_effects.append(ClickEffect.new(
			effect_kind,
			_snap_point(local_position),
			seed,
			clampf(depth_scale, 0.45, 1.25)))
	if _effects.size() > max_effects:
		_effects.pop_front()
	set_process(true)
	queue_redraw()
	return true


func active_effect_count() -> int:
	return _effects.size()


func active_effect_count_for_kind(effect_kind: int) -> int:
	var count := 0
	for effect: ClickEffect in _effects:
		if effect.kind == effect_kind:
			count += 1
	return count


func _process(delta: float) -> void:
	for effect: ClickEffect in _effects:
		effect.age += delta
	for index: int in range(_effects.size() - 1, -1, -1):
		if _effects[index].age >= _lifetime_for_kind(_effects[index].kind):
			_effects.remove_at(index)
	queue_redraw()
	if _effects.is_empty():
		set_process(false)


func _draw() -> void:
	for effect: ClickEffect in _effects:
		var lifetime := _lifetime_for_kind(effect.kind)
		var phase := clampf(effect.age / lifetime, 0.0, 1.0)
		match effect.kind:
			EffectKind.FOREGROUND_SPARK:
				_draw_foreground_spark(effect, phase)
			EffectKind.MAGMA_BUBBLE:
				_draw_magma_bubble(effect, phase)
			EffectKind.MIDGROUND_SPIT:
				_draw_midground_spit(effect, phase)
			_:
				pass


func _draw_foreground_spark(effect: ClickEffect, phase: float) -> void:
	var scale := effect.depth_scale
	var fade := (1.0 - phase) * (1.0 - phase)
	var impact_open := 1.0 - clampf(phase / 0.28, 0.0, 1.0)
	var core := spark_core_color
	core.a *= fade
	var hot := spark_hot_color
	hot.a *= fade
	var tail := spark_tail_color
	tail.a *= fade * 0.82
	var px := pixel_size * scale

	if impact_open > 0.0:
		var cross_reach := px * lerpf(2.0, 4.5, 1.0 - impact_open)
		draw_rect(Rect2(
				_snap_point(effect.origin - Vector2(cross_reach, px * 0.5)),
				Vector2(cross_reach * 2.0, px)), hot)
		draw_rect(Rect2(
				_snap_point(effect.origin - Vector2(px * 0.5, cross_reach)),
				Vector2(px, cross_reach * 2.0)), hot)
		_draw_pixel_diamond(effect.origin, px * 1.6, core)

	for index: int in 9:
		var spread := float(index) / 8.0
		var angle := lerpf(-2.88, -0.26, spread)
		angle += (_hash(effect.seed, float(index)) - 0.5) * 0.22
		var speed := lerpf(72.0, 138.0,
				_hash(effect.seed + 17.0, float(index))) * scale
		var velocity := Vector2(cos(angle), sin(angle)) * speed
		var position := effect.origin + velocity * effect.age
		position.y += 150.0 * scale * effect.age * effect.age
		position = _snap_point(position)
		var trail_length := px * (2.6 if index < 3 else 1.7)
		var trail_end := _snap_point(
				position - velocity.normalized() * trail_length)
		draw_line(trail_end, position, tail, maxf(px * 0.72, 2.0), false)
		_draw_pixel_diamond(position, px * (0.92 if index < 3 else 0.68),
				core if index < 2 else hot)


func _draw_magma_bubble(effect: ClickEffect, phase: float) -> void:
	var scale := effect.depth_scale
	var px := pixel_size * scale
	var rise_phase := clampf(phase / 0.56, 0.0, 1.0)
	var bulge := sin(rise_phase * PI * 0.5)
	var pop_phase := clampf((phase - 0.52) / 0.48, 0.0, 1.0)
	var bubble_fade := 1.0 - smoothstep(0.52, 0.76, phase)
	var center := effect.origin - Vector2(0.0, px * 1.6 * bulge)
	var radius := Vector2(
			lerpf(px * 1.4, px * 4.8, bulge),
			lerpf(px * 0.8, px * 2.7, bulge))

	var shadow := magma_shadow_color
	shadow.a *= bubble_fade
	var body := magma_body_color
	body.a *= bubble_fade
	var hot := magma_hot_color
	hot.a *= bubble_fade
	var core := magma_core_color
	core.a *= bubble_fade
	if bubble_fade > 0.0:
		_draw_filled_pixel_ellipse(center + Vector2(0.0, px), radius, shadow)
		_draw_filled_pixel_ellipse(center, radius * Vector2(0.92, 0.86), body)
		_draw_broken_ellipse(center, radius, hot, effect.seed, 0.18)
		_draw_broken_ellipse(
				center - Vector2(radius.x * 0.16, radius.y * 0.18),
				radius * Vector2(0.48, 0.42), core,
				effect.seed + 31.0, 0.48)

	var ripple_phase := clampf((phase - 0.15) / 0.85, 0.0, 1.0)
	if phase > 0.15:
		var ripple := magma_hot_color
		ripple.a *= (1.0 - ripple_phase) * 0.78
		_draw_broken_ellipse(
				effect.origin + Vector2(0.0, px * 0.7),
				Vector2(
						lerpf(px * 2.0, px * 11.0, ripple_phase),
						lerpf(px * 0.7, px * 2.2, ripple_phase)),
				ripple, effect.seed + 47.0, 0.32)

	if pop_phase <= 0.0:
		return
	var droplet_fade := (1.0 - pop_phase) * (1.0 - pop_phase)
	for index: int in 5:
		var direction := lerpf(-1.0, 1.0, float(index) / 4.0)
		var reach := px * lerpf(3.0, 8.5,
				_hash(effect.seed + 73.0, float(index)))
		var height := px * lerpf(4.0, 8.0,
				_hash(effect.seed + 101.0, float(index)))
		var droplet_position := center + Vector2(
				direction * reach * pop_phase,
				-height * 4.0 * pop_phase * (1.0 - pop_phase)
						+ px * 2.2 * pop_phase)
		var droplet_color := magma_core_color if index < 2 else magma_hot_color
		droplet_color.a *= droplet_fade
		_draw_pixel_diamond(_snap_point(droplet_position),
				px * (0.86 if index < 2 else 0.64), droplet_color)


func _draw_midground_spit(effect: ClickEffect, phase: float) -> void:
	var scale := effect.depth_scale
	var px := pixel_size * scale
	var fade := (1.0 - phase) * (1.0 - phase)
	var ring := magma_hot_color
	ring.a *= fade * 0.92
	var core := magma_core_color
	core.a *= fade
	var body := magma_body_color
	body.a *= fade * 0.76
	_draw_broken_ellipse(
			effect.origin,
			Vector2(
					lerpf(px * 1.2, px * 5.4, phase),
					lerpf(px * 0.8, px * 2.2, phase)),
			ring, effect.seed, 0.28)
	if phase < 0.22:
		_draw_pixel_diamond(effect.origin, px * 1.5, core)

	for index: int in 6:
		var spread := lerpf(-0.92, 0.92, float(index) / 5.0)
		var speed_x := spread * lerpf(28.0, 54.0,
				_hash(effect.seed + 19.0, float(index))) * scale
		var speed_y := -lerpf(45.0, 92.0,
				_hash(effect.seed + 53.0, float(index))) * scale
		var droplet_position := effect.origin + Vector2(
				speed_x * effect.age,
				speed_y * effect.age + 128.0 * scale * effect.age * effect.age)
		_draw_pixel_diamond(_snap_point(droplet_position),
				px * (0.82 if index < 2 else 0.58),
				core if index < 2 else body)


func _draw_filled_pixel_ellipse(
		center: Vector2,
		radius: Vector2,
		color: Color
) -> void:
	if color.a <= 0.0 or radius.x <= 0.0 or radius.y <= 0.0:
		return
	var rows := maxi(1, int(ceil(radius.y / pixel_size)))
	for row: int in range(-rows, rows + 1):
		var y := float(row) * pixel_size
		var normalized_y := clampf(y / radius.y, -1.0, 1.0)
		var half_width := sqrt(maxf(0.0, 1.0 - normalized_y * normalized_y)) \
				* radius.x
		var start := _snap_point(center + Vector2(-half_width, y))
		var width := maxf(pixel_size,
				floor(half_width * 2.0 / pixel_size + 0.5) * pixel_size)
		draw_rect(Rect2(start, Vector2(width, pixel_size)), color)


func _draw_broken_ellipse(
		center: Vector2,
		radius: Vector2,
		color: Color,
		seed: float,
		skip_ratio: float
) -> void:
	if color.a <= 0.0:
		return
	for segment: int in 28:
		if _hash(seed, float(segment)) < skip_ratio:
			continue
		var angle_a := TAU * float(segment) / 28.0
		var angle_b := TAU * float(segment + 1) / 28.0
		var point_a := _snap_point(center + Vector2(
				cos(angle_a) * radius.x, sin(angle_a) * radius.y))
		var point_b := _snap_point(center + Vector2(
				cos(angle_b) * radius.x, sin(angle_b) * radius.y))
		draw_line(point_a, point_b, color, pixel_size, false)


func _draw_pixel_diamond(center: Vector2, diameter: float, color: Color) -> void:
	if color.a <= 0.0:
		return
	var snapped_center := _snap_point(center)
	var px := maxf(pixel_size, floor(diameter / pixel_size + 0.5) * pixel_size)
	draw_rect(Rect2(
			snapped_center - Vector2(px * 0.5, pixel_size * 0.5),
			Vector2(px, pixel_size)), color)
	if px > pixel_size:
		draw_rect(Rect2(
				snapped_center - Vector2(pixel_size * 0.5, px * 0.5),
				Vector2(pixel_size, px)), color)


func _lifetime_for_kind(effect_kind: int) -> float:
	match effect_kind:
		EffectKind.FOREGROUND_SPARK:
			return SPARK_LIFETIME_SEC
		EffectKind.MAGMA_BUBBLE:
			return BUBBLE_LIFETIME_SEC
		EffectKind.MIDGROUND_SPIT:
			return SPIT_LIFETIME_SEC
		_:
			return 0.01


func _snap_point(point: Vector2) -> Vector2:
	return (point / pixel_size).round() * pixel_size


func _hash(seed: float, index: float) -> float:
	return fposmod(sin(seed * 12.9898 + index * 78.233) * 43758.5453, 1.0)
