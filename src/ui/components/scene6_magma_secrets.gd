class_name Scene6MagmaSecrets
extends Control

## One-at-a-time molten-lake discoveries. A qualified click during an active
## rise or cooldown produces only a splash; it is never queued for later.

enum SecretKind {
	SWORD_HILT,
	SWORD_TIP,
	LEGENDARY_BLADE,
}

signal secret_revealed(secret_kind: int, valid_click_count: int)
signal secret_submerged(secret_kind: int)
signal reveal_suppressed(canvas_position: Vector2)

@export var sword_hilt_texture: Texture2D
@export var sword_tip_texture: Texture2D
@export var legendary_blade_texture: Texture2D
@export var front_props_layer_path := NodePath("../MagmaSecretFrontProps")
@export var platform_path := NodePath("../BattlePlatform")
@export_range(2, 10, 1) var clicks_per_reveal: int = 4
@export_range(2.5, 7.0, 0.1) var reveal_cooldown_sec: float = 4.1
@export_range(0.01, 0.30, 0.01) var legendary_chance: float = 0.10
@export_range(3, 16, 1) var legendary_pity_ordinary_spawns: int = 8
@export_range(-1.0, 1.0, 0.01) var legend_roll_override: float = -1.0
@export_range(1.0, 4.0, 0.5) var ordinary_scale: float = 2.0
@export_range(1.0, 4.0, 0.5) var legendary_scale: float = 3.0
@export var reference_canvas_size := Vector2(1920.0, 1080.0)
@export_range(0.25, 1.2, 0.05) var rise_duration_sec: float = 0.66
@export_range(0.4, 2.0, 0.05) var float_duration_sec: float = 1.05
@export_range(0.6, 2.5, 0.05) var sink_duration_sec: float = 1.30
@export_range(1.0, 3.0, 0.05) var legendary_rise_duration_sec: float = 1.85
@export_range(1.0, 5.0, 0.05) var legendary_float_duration_sec: float = 3.20
@export_range(1.4, 4.0, 0.05) var legendary_sink_duration_sec: float = 2.35
@export_range(2.0, 8.0, 1.0) var bob_distance_px: float = 3.0
@export_range(4.0, 32.0, 1.0) var legendary_hover_clearance_px: float = 8.0
@export_range(1.0, 6.0, 1.0) var legendary_hover_bob_px: float = 2.0
@export_range(0.0, 16.0, 1.0) var submerge_padding_px: float = 4.0
@export_range(0.45, 0.9, 0.01) var hilt_visible_fraction: float = 0.78
@export_range(0.45, 0.9, 0.01) var tip_visible_fraction: float = 0.64
@export_range(0.45, 0.80, 0.01) var front_depth_ratio: float = 0.62

const RIPPLE_LIFETIME_SEC := 0.72
const RIPPLE_PIXEL_SIZE := 4.0
const CLOSURE_BUBBLE_LIFETIME_SEC := 0.62
const FORGE_AURA_SHADER := preload(
		"res://assets/shaders/canvas_env_scene6_forge_aura.gdshader")
const FORGE_AURA_SIZE := Vector2(240.0, 176.0)


class RippleState:
	var origin: Vector2
	var age: float = 0.0
	var seed: float
	var splash_only: bool
	var legendary: bool
	var submerge: bool

	func _init(
			ripple_origin: Vector2,
			ripple_seed: float,
			is_splash_only: bool,
			is_legendary: bool,
			is_submerge: bool = false
	) -> void:
		origin = ripple_origin
		seed = ripple_seed
		splash_only = is_splash_only
		legendary = is_legendary
		submerge = is_submerge


class ClosureBubbleState:
	var origin: Vector2
	var age: float = 0.0
	var seed: float

	func _init(bubble_origin: Vector2, bubble_seed: float) -> void:
		origin = bubble_origin
		seed = bubble_seed


var _valid_click_count: int = 0
var _next_ordinary_kind: int = SecretKind.SWORD_HILT
var _hilt_spawn_count: int = 0
var _tip_spawn_count: int = 0
var _legendary_spawn_count: int = 0
var _ordinary_since_legendary: int = 0
var _suppressed_reveal_count: int = 0
var _active_pocket: Control
var _active_kind: int = -1
var _last_spawn_kind: int = -1
var _next_allowed_reveal_msec: int = 0
var _ripples: Array[RippleState] = []
var _rng := RandomNumberGenerator.new()
var _legendary_forge_aura: ColorRect
var _active_sprite: Sprite2D
var _active_surface_position := Vector2.ZERO
var _return_contact_armed: bool = false
var _return_contact_ripple_count: int = 0
var _closure_bubbles: Array[ClosureBubbleState] = []
var _closure_bubble_spawn_count: int = 0
var _front_props_layer: Control
var _platform: TextureRect
var _active_front_depth: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front_props_layer = get_node_or_null(front_props_layer_path) as Control
	_platform = get_node_or_null(platform_path) as TextureRect
	_rng.randomize()
	set_process(false)


func register_molten_click(canvas_position: Vector2) -> void:
	_valid_click_count += 1
	if _valid_click_count % maxi(clicks_per_reveal, 1) != 0:
		return
	var local_position := get_global_transform_with_canvas().affine_inverse() \
			* canvas_position
	if active_secret_count() > 0 \
			or Time.get_ticks_msec() < _next_allowed_reveal_msec:
		_suppressed_reveal_count += 1
		_spawn_ripple(local_position.round(), true, false)
		reveal_suppressed.emit(canvas_position)
		return
	var secret_kind := _select_secret_kind()
	_spawn_secret(secret_kind, local_position)


func get_valid_click_count() -> int:
	return _valid_click_count


func get_hilt_spawn_count() -> int:
	return _hilt_spawn_count


func get_tip_spawn_count() -> int:
	return _tip_spawn_count


func get_legendary_spawn_count() -> int:
	return _legendary_spawn_count


func get_suppressed_reveal_count() -> int:
	return _suppressed_reveal_count


func get_last_spawn_kind() -> int:
	return _last_spawn_kind


func get_active_kind() -> int:
	return _active_kind


func active_secret_count() -> int:
	if not is_instance_valid(_active_pocket) \
			or _active_pocket.is_queued_for_deletion():
		_active_pocket = null
		_active_kind = -1
		_active_front_depth = false
	return 1 if _active_pocket != null else 0


func pending_secret_count() -> int:
	return 0


func active_ripple_count() -> int:
	return _ripples.size()


func active_return_ripple_count() -> int:
	var count := 0
	for ripple: RippleState in _ripples:
		if ripple.submerge:
			count += 1
	return count


func get_return_contact_ripple_count() -> int:
	return _return_contact_ripple_count


func get_closure_bubble_spawn_count() -> int:
	return _closure_bubble_spawn_count


func active_closure_bubble_count() -> int:
	return _closure_bubbles.size()


func is_active_secret_in_front_depth() -> bool:
	return active_secret_count() > 0 and _active_front_depth


func get_active_secret_pocket() -> Control:
	return _active_pocket if active_secret_count() > 0 else null


func get_active_secret_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if active_secret_count() == 0:
		return positions
	positions.append(_active_pocket.get_global_transform_with_canvas() * Vector2(
			_active_pocket.size.x * 0.5, _active_pocket.size.y - 4.0))
	return positions


func _select_secret_kind() -> int:
	var forced_by_pity := legendary_pity_ordinary_spawns > 0 \
			and _ordinary_since_legendary >= legendary_pity_ordinary_spawns
	var roll := legend_roll_override if legend_roll_override >= 0.0 \
			else _rng.randf()
	if legendary_blade_texture != null \
			and (forced_by_pity or roll < legendary_chance):
		_ordinary_since_legendary = 0
		return SecretKind.LEGENDARY_BLADE
	var selected := _next_ordinary_kind
	_next_ordinary_kind = SecretKind.SWORD_TIP \
			if selected == SecretKind.SWORD_HILT else SecretKind.SWORD_HILT
	_ordinary_since_legendary += 1
	return selected


func _spawn_secret(secret_kind: int, local_click: Vector2) -> void:
	var texture := _texture_for_kind(secret_kind)
	if texture == null:
		return
	var prop_scale := legendary_scale \
			if secret_kind == SecretKind.LEGENDARY_BLADE else ordinary_scale
	var display_size := Vector2(texture.get_size()) * prop_scale
	var spawn_bounds := Vector2(
			maxf(size.x, reference_canvas_size.x),
			maxf(size.y, reference_canvas_size.y))
	var pocket_width := maxf(80.0, display_size.x + 28.0)
	var surface_y := clampf(local_click.y, 36.0, spawn_bounds.y - 8.0)
	var pocket_top := maxf(0.0, surface_y - display_size.y - 20.0)
	var pocket_left := clampf(
			local_click.x - pocket_width * 0.5, 0.0,
			spawn_bounds.x - pocket_width)
	var pocket := Control.new()
	pocket.name = _pocket_name_for_kind(secret_kind)
	pocket.position = Vector2(pocket_left, pocket_top).round()
	pocket.size = Vector2(pocket_width, surface_y - pocket_top + 4.0).round()
	pocket.clip_contents = true
	pocket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var front_depth := _should_use_front_depth(local_click)
	var pocket_parent: Control = _front_props_layer if front_depth else self
	pocket_parent.add_child(pocket)

	var sprite := Sprite2D.new()
	sprite.name = _sprite_name_for_kind(secret_kind)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = texture
	sprite.scale = Vector2(prop_scale, prop_scale)
	pocket.add_child(sprite)
	var surface_local_y := pocket.size.y - 4.0
	var half_height := display_size.y * 0.5
	var peak_y := surface_local_y - half_height - legendary_hover_clearance_px \
			if secret_kind == SecretKind.LEGENDARY_BLADE \
			else surface_local_y + half_height \
					- display_size.y * _visible_fraction_for_kind(secret_kind)
	var peak_position := Vector2(pocket.size.x * 0.5, peak_y).round()
	var submerged_position := Vector2(
			peak_position.x,
			surface_local_y + half_height + submerge_padding_px).round()
	sprite.position = submerged_position
	_active_pocket = pocket
	_active_kind = secret_kind
	_active_front_depth = front_depth
	_last_spawn_kind = secret_kind
	_next_allowed_reveal_msec = Time.get_ticks_msec() \
			+ int(reveal_cooldown_sec * 1000.0)
	match secret_kind:
		SecretKind.SWORD_HILT:
			_hilt_spawn_count += 1
		SecretKind.SWORD_TIP:
			_tip_spawn_count += 1
		SecretKind.LEGENDARY_BLADE:
			_legendary_spawn_count += 1
		_:
			pass
	var legendary := secret_kind == SecretKind.LEGENDARY_BLADE
	var surface_position := Vector2(local_click.x, surface_y).round()
	_active_sprite = sprite
	_active_surface_position = surface_position
	_return_contact_armed = false
	if legendary:
		_spawn_legendary_forge_aura(surface_position, front_depth)
	_spawn_ripple(surface_position, false, legendary)
	_animate_secret(sprite, pocket, submerged_position, peak_position,
			surface_position, secret_kind)
	secret_revealed.emit(secret_kind, _valid_click_count)


func _animate_secret(
		sprite: Sprite2D,
		pocket: Control,
		submerged_position: Vector2,
		peak_position: Vector2,
		surface_position: Vector2,
		secret_kind: int
) -> void:
	var legendary := secret_kind == SecretKind.LEGENDARY_BLADE
	var rise_duration := legendary_rise_duration_sec if legendary \
			else rise_duration_sec
	var float_duration := legendary_float_duration_sec if legendary \
			else float_duration_sec
	var sink_duration := legendary_sink_duration_sec if legendary \
			else sink_duration_sec
	if legendary:
		# Preserve the authored dark-iron/magma palette. The reveal warms gently
		# instead of flashing through red and white as the earlier version did.
		sprite.modulate = Color(0.88, 0.76, 0.57, 1.0)
		var color_tween := create_tween()
		color_tween.tween_property(
				sprite, "modulate", Color(1.0, 0.95, 0.82, 1.0),
				rise_duration * 0.92) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var tween := create_tween()
	var rise_step := tween.tween_property(
			sprite, "position", peak_position, rise_duration)
	if legendary:
		rise_step.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		rise_step.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	var hover_distance := legendary_hover_bob_px if legendary else bob_distance_px
	tween.tween_property(sprite, "position:y", peak_position.y + hover_distance,
			float_duration * 0.23) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "position:y",
			peak_position.y - hover_distance * 0.70,
			float_duration * 0.29) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "position:y",
			peak_position.y + hover_distance * 0.35,
			float_duration * 0.27) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "position:y", peak_position.y,
			float_duration * 0.21) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void:
		if is_instance_valid(pocket) and _active_pocket == pocket:
			_return_contact_armed = true
			# The opening ripple may have already stopped this component's process
			# loop during a long hover. Re-arm it for geometry-based water contact.
			set_process(true)
	)
	var sink_step := tween.tween_property(
			sprite, "position", submerged_position, sink_duration)
	if legendary:
		sink_step.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		sink_step.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		if not is_instance_valid(pocket) or _active_pocket != pocket:
			return
		_spawn_closure_bubble(surface_position, legendary)
		secret_submerged.emit(secret_kind)
		_active_pocket = null
		_active_sprite = null
		_active_kind = -1
		_active_front_depth = false
		_return_contact_armed = false
		pocket.queue_free()
	)


func _spawn_ripple(
		local_position: Vector2,
		splash_only: bool,
		legendary: bool,
		submerge: bool = false
) -> void:
	var seed := float(_valid_click_count * 31 + (17 if legendary else 0)) \
			+ local_position.x * 0.013
	_ripples.append(RippleState.new(
			local_position, seed, splash_only, legendary, submerge))
	set_process(true)
	queue_redraw()


func _spawn_closure_bubble(local_position: Vector2, legendary: bool) -> void:
	_closure_bubble_spawn_count += 1
	var seed := float(_closure_bubble_spawn_count * 43) \
			+ local_position.x * 0.017 + (11.0 if legendary else 0.0)
	_closure_bubbles.append(ClosureBubbleState.new(local_position, seed))
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	for ripple: RippleState in _ripples:
		ripple.age += delta
	for bubble: ClosureBubbleState in _closure_bubbles:
		bubble.age += delta
	_try_trigger_return_contact_ripple()
	for index: int in range(_ripples.size() - 1, -1, -1):
		var lifetime := _ripple_lifetime(_ripples[index])
		if _ripples[index].age >= lifetime:
			_ripples.remove_at(index)
	for index: int in range(_closure_bubbles.size() - 1, -1, -1):
		if _closure_bubbles[index].age >= CLOSURE_BUBBLE_LIFETIME_SEC:
			_closure_bubbles.remove_at(index)
	_update_legendary_forge_aura()
	queue_redraw()
	if _ripples.is_empty() and _closure_bubbles.is_empty() \
			and not _return_contact_armed:
		set_process(false)


func _try_trigger_return_contact_ripple() -> void:
	if not _return_contact_armed or not is_instance_valid(_active_pocket) \
			or not is_instance_valid(_active_sprite):
		return
	var texture := _active_sprite.texture
	if texture == null:
		return
	var sprite_bottom_canvas := _active_sprite.get_global_transform_with_canvas() \
			* Vector2(0.0, float(texture.get_height()) * 0.5)
	var sprite_bottom := (get_global_transform_with_canvas().affine_inverse() \
			* sprite_bottom_canvas).y
	if sprite_bottom < _active_surface_position.y - 0.5:
		return
	_return_contact_armed = false
	_return_contact_ripple_count += 1
	_spawn_ripple(_active_surface_position, false, false, true)


func _draw() -> void:
	for ripple: RippleState in _ripples:
		var lifetime := _ripple_lifetime(ripple)
		var full_phase := clampf(ripple.age / lifetime, 0.0, 1.0)
		if ripple.legendary:
			_draw_legendary_accents(ripple, full_phase)
			continue
		var surface_phase := clampf(
				ripple.age / RIPPLE_LIFETIME_SEC, 0.0, 1.0)
		var opening := sin(clampf(surface_phase / 0.72, 0.0, 1.0) * PI * 0.5)
		var fade := (1.0 - surface_phase) * (1.0 - surface_phase)
		var max_radius := 44.0 if ripple.submerge \
				else 42.0 if ripple.splash_only else 50.0
		var hot := Color(0.70, 0.09, 0.018, 0.48 * fade) \
				if ripple.submerge \
				else Color(0.92, 0.16, 0.025, 0.66 * fade)
		var core := Color(0.94, 0.29, 0.045, 0.32 * fade) \
				if ripple.submerge \
				else Color(1.0, 0.48, 0.08, 0.50 * fade)
		_draw_broken_ripple(ripple.origin,
				Vector2(lerpf(10.0, max_radius, opening),
						lerpf(3.0, 8.0, opening)),
				hot, ripple.seed,
				0.38 if ripple.submerge \
				else 0.30 if ripple.splash_only else 0.26)
		if surface_phase >= 0.12:
			var inner_phase := clampf(
					(surface_phase - 0.12) / 0.88, 0.0, 1.0)
			_draw_broken_ripple(ripple.origin,
					Vector2(lerpf(6.0, 29.0, inner_phase),
							lerpf(2.0, 6.0, inner_phase)),
					core, ripple.seed + 19.0,
					0.50 if ripple.submerge \
					else 0.42 if ripple.splash_only else 0.36)
	for bubble: ClosureBubbleState in _closure_bubbles:
		_draw_closure_bubble(bubble)


func _draw_closure_bubble(bubble: ClosureBubbleState) -> void:
	var phase := clampf(
			bubble.age / CLOSURE_BUBBLE_LIFETIME_SEC, 0.0, 1.0)
	var grow := smoothstep(0.0, 0.22, phase)
	var pop := smoothstep(0.68, 1.0, phase)
	var drift_sign := -1.0 if _hash(bubble.seed, 3.0) < 0.5 else 1.0
	var center := bubble.origin + Vector2(
			drift_sign * smoothstep(0.12, 0.86, phase) * 3.0,
			-2.0 - smoothstep(0.0, 0.82, phase) * 9.0)
	center = _snap_point(center)
	var radius := Vector2(
			lerpf(3.0, 7.0, grow) * lerpf(1.0, 1.28, pop),
			lerpf(2.0, 5.0, grow) * lerpf(1.0, 0.30, pop))
	var alpha := grow * (1.0 - pop)
	var body := Color(0.27, 0.025, 0.008, 0.66 * alpha)
	var rim := Color(0.91, 0.19, 0.025, 0.68 * alpha)
	var core := Color(1.0, 0.43, 0.07, 0.42 * alpha)
	var silhouette := PackedVector2Array([
		_snap_point(center + Vector2(-radius.x * 0.55, -radius.y)),
		_snap_point(center + Vector2(radius.x * 0.55, -radius.y)),
		_snap_point(center + Vector2(radius.x, -radius.y * 0.25)),
		_snap_point(center + Vector2(radius.x, radius.y * 0.35)),
		_snap_point(center + Vector2(radius.x * 0.45, radius.y)),
		_snap_point(center + Vector2(-radius.x * 0.45, radius.y)),
		_snap_point(center + Vector2(-radius.x, radius.y * 0.35)),
		_snap_point(center + Vector2(-radius.x, -radius.y * 0.25)),
	])
	draw_colored_polygon(silhouette, body)
	_draw_broken_ripple(center, radius, rim, bubble.seed, 0.42)
	if phase < 0.72:
		draw_rect(Rect2(_snap_point(center + Vector2(-2.0, -radius.y)),
				Vector2(4.0, 4.0)), core)


func _ripple_lifetime(ripple: RippleState) -> float:
	if not ripple.legendary:
		return RIPPLE_LIFETIME_SEC
	return legendary_rise_duration_sec + legendary_float_duration_sec \
			+ legendary_sink_duration_sec


func _draw_legendary_accents(
		ripple: RippleState,
		phase: float
) -> void:
	# The shader child owns the irregular furnace mist. Parent custom drawing is
	# kept only for lake contact seams and the already-approved cinders.
	var presence := _legendary_light_presence(phase)
	var forge_center := ripple.origin + Vector2(0.0, 5.0)
	_draw_forge_surface_seams(forge_center, ripple.age, ripple.seed, presence)
	_draw_forge_cinders(forge_center, ripple.age, ripple.seed, presence)


func _legendary_light_presence(phase: float) -> float:
	var total_duration := legendary_rise_duration_sec \
			+ legendary_float_duration_sec + legendary_sink_duration_sec
	var sink_start_phase := (legendary_rise_duration_sec \
			+ legendary_float_duration_sec) / maxf(total_duration, 0.001)
	var fade_in := smoothstep(0.0, 0.12, phase)
	var fade_out := 1.0 - smoothstep(sink_start_phase, 1.0, phase)
	return fade_in * fade_out


func _spawn_legendary_forge_aura(
		surface_position: Vector2,
		front_depth: bool
) -> void:
	_clear_legendary_forge_aura()
	var aura := ColorRect.new()
	aura.name = "LegendaryForgeAuraRuntime"
	aura.position = (surface_position \
			- Vector2(FORGE_AURA_SIZE.x * 0.5, FORGE_AURA_SIZE.y - 8.0)).round()
	aura.size = FORGE_AURA_SIZE
	aura.color = Color.WHITE
	aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aura.z_index = 0
	var aura_material := ShaderMaterial.new()
	aura_material.shader = FORGE_AURA_SHADER
	aura_material.set_shader_parameter("size_px", FORGE_AURA_SIZE)
	aura_material.set_shader_parameter("pixel_px", RIPPLE_PIXEL_SIZE)
	aura_material.set_shader_parameter("presence", 0.0)
	aura_material.set_shader_parameter("seed",
			float(_valid_click_count * 31 + 17) + surface_position.x * 0.013)
	aura.material = aura_material
	if front_depth and is_instance_valid(_front_props_layer):
		_front_props_layer.add_child(aura)
		# The furnace glow shares the selected depth band but stays behind its prop.
		_front_props_layer.move_child(aura, 0)
	else:
		var environment_parent := get_parent()
		environment_parent.add_child(aura)
		# Back-depth light remains behind the platform and foreground.
		environment_parent.move_child(aura, get_index())
	_legendary_forge_aura = aura


func _should_use_front_depth(local_click: Vector2) -> bool:
	if not is_instance_valid(_front_props_layer) or not is_instance_valid(_platform):
		return false
	var click_canvas := get_global_transform_with_canvas() * local_click
	var platform_transform := _platform.get_global_transform_with_canvas()
	var platform_top := platform_transform * Vector2.ZERO
	var platform_bottom := platform_transform * Vector2(0.0, _platform.size.y)
	var depth_split_y := lerpf(
			platform_top.y, platform_bottom.y, front_depth_ratio)
	return click_canvas.y >= depth_split_y


func _update_legendary_forge_aura() -> void:
	if not is_instance_valid(_legendary_forge_aura):
		_legendary_forge_aura = null
		return
	var legendary_ripple: RippleState
	for ripple: RippleState in _ripples:
		if ripple.legendary:
			legendary_ripple = ripple
			break
	if legendary_ripple == null:
		_clear_legendary_forge_aura()
		return
	var phase := clampf(
			legendary_ripple.age / _ripple_lifetime(legendary_ripple),
			0.0, 1.0)
	var aura_material := _legendary_forge_aura.material as ShaderMaterial
	if aura_material != null:
		aura_material.set_shader_parameter(
				"presence", _legendary_light_presence(phase))


func _clear_legendary_forge_aura() -> void:
	if not is_instance_valid(_legendary_forge_aura):
		_legendary_forge_aura = null
		return
	var old_aura := _legendary_forge_aura
	_legendary_forge_aura = null
	var aura_parent := old_aura.get_parent()
	if aura_parent != null:
		aura_parent.remove_child(old_aura)
	old_aura.queue_free()


func _draw_forge_surface_seams(
		center: Vector2,
		age: float,
		seed: float,
		presence: float
) -> void:
	# A broad low-contrast heat bed and four broken seams keep the light inside
	# the lake texture. The old six full-length gold spokes read like a pasted
	# decal because every line converged on one mathematically clean center.
	var heat_bed := PackedVector2Array([
		_snap_point(center + Vector2(-64.0, 5.0)),
		_snap_point(center + Vector2(-43.0, -9.0)),
		_snap_point(center + Vector2(-10.0, -5.0)),
		_snap_point(center + Vector2(18.0, -11.0)),
		_snap_point(center + Vector2(61.0, -3.0)),
		_snap_point(center + Vector2(53.0, 12.0)),
		_snap_point(center + Vector2(11.0, 8.0)),
		_snap_point(center + Vector2(-31.0, 14.0)),
	])
	draw_colored_polygon(heat_bed,
			Color(0.42, 0.055, 0.018, 0.16 * presence))
	var seams: Array[PackedVector2Array] = [
		PackedVector2Array([
			Vector2(-10.0, 1.0), Vector2(-25.0, -2.0),
			Vector2(-34.0, -6.0), Vector2(-52.0, -4.0)]),
		PackedVector2Array([
			Vector2(-5.0, 4.0), Vector2(-16.0, 12.0),
			Vector2(-23.0, 14.0), Vector2(-35.0, 10.0)]),
		PackedVector2Array([
			Vector2(8.0, 3.0), Vector2(19.0, 10.0),
			Vector2(28.0, 11.0), Vector2(43.0, 5.0)]),
		PackedVector2Array([
			Vector2(12.0, 0.0), Vector2(29.0, -7.0),
			Vector2(38.0, -8.0), Vector2(56.0, -3.0)]),
	]
	for index: int in seams.size():
		var seam := seams[index]
		var travel := 0.5 + 0.5 * sin(age * 0.82 + seed * 0.03 + index * 1.9)
		var base_color := Color(0.55, 0.075, 0.018,
				presence * lerpf(0.20, 0.26, travel))
		var hot_color := Color(0.86, 0.20, 0.035,
				presence * lerpf(0.08, 0.15, travel))
		for pair_start: int in [0, 2]:
			var point_a := _snap_point(center + seam[pair_start])
			var point_b := _snap_point(center + seam[pair_start + 1])
			draw_line(point_a, point_b, base_color, 5.0, false)
			draw_line(point_a, point_b, hot_color, 2.0, false)


func _draw_forge_cinders(
		center: Vector2,
		age: float,
		seed: float,
		presence: float
) -> void:
	for index: int in 7:
		var cycle := fposmod(age * (0.16 + index * 0.012)
				+ seed * 0.011 + index * 0.137, 1.0)
		var x_offset := sin(seed * 0.09 + index * 2.1 + cycle * 2.4) \
				* (18.0 + float(index % 3) * 7.0)
		var y_offset := -18.0 - cycle * (72.0 + float(index % 2) * 22.0)
		var cinder_alpha := presence * sin(cycle * PI) * 0.44
		var cinder_size := 4.0 if index % 3 != 0 else 6.0
		draw_rect(Rect2(
				_snap_point(center + Vector2(x_offset, y_offset)),
				Vector2(cinder_size, cinder_size)),
				Color(1.0, 0.48, 0.06, cinder_alpha))


func _draw_broken_ripple(
		center: Vector2,
		radius: Vector2,
		color: Color,
		seed: float,
		skip_ratio: float
) -> void:
	for segment: int in 24:
		if _hash(seed, float(segment)) < skip_ratio:
			continue
		var angle_a := TAU * float(segment) / 24.0
		var angle_b := TAU * float(segment + 1) / 24.0
		var point_a := _snap_point(center + Vector2(
				cos(angle_a) * radius.x, sin(angle_a) * radius.y))
		var point_b := _snap_point(center + Vector2(
				cos(angle_b) * radius.x, sin(angle_b) * radius.y))
		draw_line(point_a, point_b, color, RIPPLE_PIXEL_SIZE, false)


func _texture_for_kind(secret_kind: int) -> Texture2D:
	match secret_kind:
		SecretKind.SWORD_HILT:
			return sword_hilt_texture
		SecretKind.SWORD_TIP:
			return sword_tip_texture
		SecretKind.LEGENDARY_BLADE:
			return legendary_blade_texture
		_:
			return null


func _visible_fraction_for_kind(secret_kind: int) -> float:
	match secret_kind:
		SecretKind.SWORD_HILT:
			return hilt_visible_fraction
		SecretKind.SWORD_TIP:
			return tip_visible_fraction
		SecretKind.LEGENDARY_BLADE:
			return 1.0
		_:
			return 0.7


func _pocket_name_for_kind(secret_kind: int) -> String:
	match secret_kind:
		SecretKind.SWORD_HILT:
			return "HiltPocketRuntime"
		SecretKind.SWORD_TIP:
			return "TipPocketRuntime"
		SecretKind.LEGENDARY_BLADE:
			return "LegendaryPocketRuntime"
		_:
			return "SecretPocketRuntime"


func _sprite_name_for_kind(secret_kind: int) -> String:
	match secret_kind:
		SecretKind.SWORD_HILT:
			return "SwordHilt"
		SecretKind.SWORD_TIP:
			return "SwordTip"
		SecretKind.LEGENDARY_BLADE:
			return "ChiluKingsBlade"
		_:
			return "SecretProp"


func _snap_point(point: Vector2) -> Vector2:
	return (point / RIPPLE_PIXEL_SIZE).round() * RIPPLE_PIXEL_SIZE


func _hash(seed: float, index: float) -> float:
	return fposmod(sin(seed * 12.9898 + index * 78.233) * 43758.5453, 1.0)
