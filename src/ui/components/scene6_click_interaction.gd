class_name Scene6ClickInteraction
extends Node

## Scene6 click routing. Battle UI receives input first; the existing full-screen
## PreviewBackdrop forwards only the GUI events that reached the stage itself.
## The component never accepts or marks the event handled.
## Hit testing follows visual draw priority and samples source alpha / the same
## warm-pixel gates used by the midground lava shader.

enum InteractionKind {
	NONE,
	FOREGROUND_SPARK,
	MAGMA_BUBBLE,
	MIDGROUND_SPIT,
}

signal interaction_spawned(kind: int, canvas_position: Vector2)

@export_node_path("Control") var input_target_path := NodePath("../PreviewBackdrop")
@export_node_path("TextureRect") var foreground_left_path := NodePath("../ForegroundLeft")
@export_node_path("TextureRect") var foreground_right_path := NodePath("../ForegroundRight")
@export_node_path("TextureRect") var midground_left_path := NodePath("../MidgroundLeft")
@export_node_path("TextureRect") var midground_right_path := NodePath("../MidgroundRight")
@export_node_path("TextureRect") var battle_platform_path := NodePath("../BattlePlatform")
@export_node_path("ColorRect") var magma_lake_path := NodePath("../MagmaLake")
@export_node_path("Control") var foreground_fx_path := NodePath("../ForegroundClickFX")
@export_node_path("Control") var midground_fx_path := NodePath("../MidgroundClickFX")
@export_node_path("Control") var magma_fx_path := NodePath("../MagmaClickFX")
@export_node_path("Control") var magma_secrets_path := NodePath("../MagmaSecrets")

@export_range(0.01, 0.8, 0.01) var alpha_hit_threshold: float = 0.12
@export_range(0.01, 0.8, 0.01) var lava_mask_hit_threshold: float = 0.12
@export_range(0.0, 0.5, 0.01) var click_cooldown_sec: float = 0.08
@export_range(0.0, 40.0, 1.0) var magma_surface_guard_px: float = 20.0

var _foreground_left: TextureRect
var _foreground_right: TextureRect
var _midground_left: TextureRect
var _midground_right: TextureRect
var _battle_platform: TextureRect
var _magma_lake: ColorRect
var _foreground_fx: Scene6ClickEffectCanvas
var _midground_fx: Scene6ClickEffectCanvas
var _magma_fx: Scene6ClickEffectCanvas
var _magma_secrets: Scene6MagmaSecrets
var _source_images: Dictionary[StringName, Image] = {}
var _next_allowed_msec: int = 0
var _trigger_counts: Dictionary[int, int] = {}
var _input_target: Control


func _ready() -> void:
	_input_target = get_node_or_null(input_target_path) as Control
	_foreground_left = get_node_or_null(foreground_left_path) as TextureRect
	_foreground_right = get_node_or_null(foreground_right_path) as TextureRect
	_midground_left = get_node_or_null(midground_left_path) as TextureRect
	_midground_right = get_node_or_null(midground_right_path) as TextureRect
	_battle_platform = get_node_or_null(battle_platform_path) as TextureRect
	_magma_lake = get_node_or_null(magma_lake_path) as ColorRect
	_foreground_fx = get_node_or_null(foreground_fx_path) as Scene6ClickEffectCanvas
	_midground_fx = get_node_or_null(midground_fx_path) as Scene6ClickEffectCanvas
	_magma_fx = get_node_or_null(magma_fx_path) as Scene6ClickEffectCanvas
	_magma_secrets = get_node_or_null(magma_secrets_path) as Scene6MagmaSecrets
	if _input_target != null:
		if not _input_target.gui_input.is_connected(_on_input_target_gui_input):
			_input_target.gui_input.connect(_on_input_target_gui_input)
	else:
		push_warning("Scene6ClickInteraction: missing input target %s" \
				% input_target_path)

	_cache_source_image(&"ForegroundLeft", _foreground_left)
	_cache_source_image(&"ForegroundRight", _foreground_right)
	_cache_source_image(&"MidgroundLeft", _midground_left)
	_cache_source_image(&"MidgroundRight", _midground_right)
	_cache_source_image(&"BattlePlatform", _battle_platform)
	for required: Node in [
		_foreground_left,
		_foreground_right,
		_midground_left,
		_midground_right,
		_battle_platform,
		_magma_lake,
		_foreground_fx,
		_midground_fx,
		_magma_fx,
		_magma_secrets,
	]:
		if required == null:
			push_warning("Scene6ClickInteraction: a required target is missing")


func _on_input_target_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var canvas_position := _input_target.get_global_transform_with_canvas() \
			* mouse_event.position
	# Passive scene feedback: leave event consumption to the existing GUI chain.
	try_trigger_at_canvas_position(canvas_position)


func get_interaction_kind_at_canvas_position(canvas_position: Vector2) -> int:
	# Reverse draw priority: the visible foreground owns the click first.
	if _is_texture_alpha_hit(
			_foreground_right, &"ForegroundRight", canvas_position) \
			or _is_texture_alpha_hit(
					_foreground_left, &"ForegroundLeft", canvas_position):
		return InteractionKind.FOREGROUND_SPARK

	# The platform is an opaque occluder, not an interaction target. This keeps
	# lake bubbles behind the bridge instead of painting over its surface.
	if _is_texture_alpha_hit(
			_battle_platform, &"BattlePlatform", canvas_position):
		return InteractionKind.NONE

	# The lake draws above both midground assets, so it wins in the lower band.
	if _is_magma_lake_hit(canvas_position):
		return InteractionKind.MAGMA_BUBBLE

	if _is_midground_lava_hit(
			_midground_right, &"MidgroundRight", canvas_position) \
			or _is_midground_lava_hit(
					_midground_left, &"MidgroundLeft", canvas_position):
		return InteractionKind.MIDGROUND_SPIT
	return InteractionKind.NONE


func try_trigger_at_canvas_position(canvas_position: Vector2) -> bool:
	if Time.get_ticks_msec() < _next_allowed_msec:
		return false
	var interaction_kind := get_interaction_kind_at_canvas_position(canvas_position)
	var effect_canvas: Scene6ClickEffectCanvas
	var depth_scale := 1.0
	match interaction_kind:
		InteractionKind.FOREGROUND_SPARK:
			effect_canvas = _foreground_fx
		InteractionKind.MAGMA_BUBBLE:
			effect_canvas = _magma_fx
		InteractionKind.MIDGROUND_SPIT:
			effect_canvas = _midground_fx
			depth_scale = 0.72
		_:
			return false
	if effect_canvas == null:
		return false
	var effect_local := effect_canvas.get_global_transform_with_canvas() \
			.affine_inverse() * canvas_position
	if not effect_canvas.spawn_effect(interaction_kind, effect_local, depth_scale):
		return false
	_next_allowed_msec = Time.get_ticks_msec() + int(click_cooldown_sec * 1000.0)
	_trigger_counts[interaction_kind] = _trigger_counts.get(interaction_kind, 0) + 1
	if interaction_kind == InteractionKind.MAGMA_BUBBLE \
			and _magma_secrets != null:
		_magma_secrets.register_molten_click(canvas_position)
	interaction_spawned.emit(interaction_kind, canvas_position)
	return true


func get_trigger_count(interaction_kind: int) -> int:
	return _trigger_counts.get(interaction_kind, 0)


func _cache_source_image(key: StringName, target: Control) -> void:
	if target == null:
		return
	var texture: Texture2D
	if target is TextureRect:
		texture = (target as TextureRect).texture
	if texture == null:
		return
	var image := texture.get_image()
	if image != null and not image.is_empty():
		_source_images[key] = image


func _is_texture_alpha_hit(
		target: TextureRect,
		image_key: StringName,
		canvas_position: Vector2
) -> bool:
	var color := _texture_color_at(target, image_key, canvas_position)
	return color.a >= alpha_hit_threshold


func _is_midground_lava_hit(
		target: TextureRect,
		image_key: StringName,
		canvas_position: Vector2
) -> bool:
	var source := _texture_color_at(target, image_key, canvas_position)
	if source.a < alpha_hit_threshold or target == null:
		return false
	var material := target.material as ShaderMaterial
	if material == null:
		return false
	var red_threshold := _shader_float(material, &"lava_red_threshold", 0.55)
	var orange_threshold := _shader_float(material, &"lava_orange_threshold", 0.025)
	var luma_threshold := _shader_float(material, &"lava_luma_threshold", 0.22)
	var luma := source.r * 0.2126 + source.g * 0.7152 + source.b * 0.0722
	var red_gate := _smoothstep(red_threshold, red_threshold + 0.18, source.r)
	var orange_gate := _smoothstep(
			orange_threshold, orange_threshold + 0.08, source.g - source.b)
	var light_gate := _smoothstep(
			luma_threshold, luma_threshold + 0.18, luma)
	return red_gate * orange_gate * light_gate * source.a \
			>= lava_mask_hit_threshold


func _is_magma_lake_hit(canvas_position: Vector2) -> bool:
	if _magma_lake == null or not _magma_lake.is_visible_in_tree():
		return false
	var local := _magma_lake.get_global_transform_with_canvas() \
			.affine_inverse() * canvas_position
	if not Rect2(Vector2.ZERO, _magma_lake.size).has_point(local):
		return false
	var material := _magma_lake.material as ShaderMaterial
	if material == null:
		return local.y >= magma_surface_guard_px
	var size_px_value: Variant = material.get_shader_parameter(&"size_px")
	var size_px := _magma_lake.size
	if size_px_value is Vector2:
		size_px = size_px_value
	var pixel_size := _shader_float(material, &"pixel_size", 4.0)
	var px := (local / _magma_lake.size * size_px / pixel_size).floor() \
			* pixel_size
	var surface_large := _value_noise(Vector2(px.x / 148.0, 9.7))
	var surface_small := _value_noise(Vector2(px.x / 63.0, 24.1))
	var surface_profile := surface_large * 0.76 + surface_small * 0.24
	var surface_step_px := _shader_float(material, &"surface_step_px", 8.0)
	var surface_y: float = surface_step_px \
			+ floor(surface_profile * 3.0 + 0.5) * pixel_size
	if px.y < surface_y + maxf(magma_surface_guard_px, 26.0):
		return false

	var raw_depth := clampf(
			(px.y - surface_y) / maxf(size_px.y - surface_y, 1.0), 0.0, 1.0)
	var perspective_depth := pow(raw_depth, 0.72)
	var perspective_scale := raw_depth * raw_depth * (3.0 - 2.0 * raw_depth)
	var far_feature_px := _shader_float(material, &"far_feature_px", 76.0)
	var near_feature_px := _shader_float(material, &"near_feature_px", 216.0)
	var near_scale := lerpf(far_feature_px, near_feature_px, perspective_scale)
	var warp_a := _value_noise(Vector2(
			px.x / lerpf(210.0, 340.0, perspective_depth),
			perspective_depth * 2.7) + Vector2(7.4, 16.9))
	var warp_b := _value_noise(Vector2(
			px.x / lerpf(136.0, 270.0, perspective_depth),
			perspective_depth * 4.1) + Vector2(23.8, 3.6))
	var plane := Vector2(px.x / near_scale, perspective_depth * 6.2)
	plane.x += (warp_a - 0.5) * lerpf(0.34, 0.72, perspective_depth)
	plane.y += (warp_b - 0.5) * 0.30
	var raft_field := _layered_noise(
			Vector2(plane.x * 0.58, plane.y * 1.46) + Vector2(5.7, 12.4))
	var raft_detail := _layered_noise(
			Vector2(plane.x * 0.94, plane.y * 2.28) + Vector2(18.1, 4.6))
	var static_crust_topology := lerpf(raft_field, raft_detail, 0.24)
	var raft_segment := _layered_noise(
			Vector2(plane.x * 1.52, plane.y * 0.68) + Vector2(31.6, 8.2))
	var crust_coverage := _shader_float(material, &"crust_coverage", 0.72)
	var crust_threshold := lerpf(0.70, 0.52, crust_coverage)
	var crust_signed := minf(
			static_crust_topology - crust_threshold, raft_segment - 0.41)
	return crust_signed < 0.012


func _texture_color_at(
		target: TextureRect,
		image_key: StringName,
		canvas_position: Vector2
) -> Color:
	if target == null or not target.is_visible_in_tree():
		return Color.TRANSPARENT
	var image := _source_images.get(image_key) as Image
	if image == null or target.size.x <= 0.0 or target.size.y <= 0.0:
		return Color.TRANSPARENT
	var local := target.get_global_transform_with_canvas().affine_inverse() \
			* canvas_position
	var uv := _texture_uv_at(target, local, Vector2(image.get_size()))
	if uv.x < 0.0 or uv.y < 0.0 or uv.x >= 1.0 or uv.y >= 1.0:
		return Color.TRANSPARENT
	if target.flip_h:
		uv.x = 1.0 - uv.x
	if target.flip_v:
		uv.y = 1.0 - uv.y
	var pixel := Vector2i(
			clampi(int(floor(uv.x * image.get_width())), 0, image.get_width() - 1),
			clampi(int(floor(uv.y * image.get_height())), 0, image.get_height() - 1))
	return image.get_pixelv(pixel)


func _texture_uv_at(
		target: TextureRect,
		local: Vector2,
		image_size: Vector2
) -> Vector2:
	if not Rect2(Vector2.ZERO, target.size).has_point(local):
		return Vector2(-1.0, -1.0)
	match target.stretch_mode:
		TextureRect.STRETCH_SCALE:
			return local / target.size
		TextureRect.STRETCH_TILE:
			return Vector2(
					fposmod(local.x, image_size.x) / image_size.x,
					fposmod(local.y, image_size.y) / image_size.y)
		TextureRect.STRETCH_KEEP:
			return local / image_size
		TextureRect.STRETCH_KEEP_CENTERED:
			return (local - (target.size - image_size) * 0.5) / image_size
		TextureRect.STRETCH_KEEP_ASPECT:
			var fit_scale := minf(
					target.size.x / image_size.x, target.size.y / image_size.y)
			return local / (image_size * fit_scale)
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
			var fit_scale := minf(
					target.size.x / image_size.x, target.size.y / image_size.y)
			var draw_size := image_size * fit_scale
			return (local - (target.size - draw_size) * 0.5) / draw_size
		TextureRect.STRETCH_KEEP_ASPECT_COVERED:
			var cover_scale := maxf(
					target.size.x / image_size.x, target.size.y / image_size.y)
			var draw_size := image_size * cover_scale
			return (local - (target.size - draw_size) * 0.5) / draw_size
		_:
			return local / target.size


func _shader_float(
		material: ShaderMaterial,
		parameter: StringName,
		fallback: float
) -> float:
	var value: Variant = material.get_shader_parameter(parameter)
	return float(value) if value != null else fallback


func _smoothstep(edge_zero: float, edge_one: float, value: float) -> float:
	var t := clampf((value - edge_zero) / maxf(edge_one - edge_zero, 0.0001),
			0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _hash21(value: Vector2) -> float:
	var p := Vector2(_fract(value.x * 123.34), _fract(value.y * 456.21))
	var offset := p.dot(p + Vector2(45.32, 45.32))
	p += Vector2(offset, offset)
	return _fract(p.x * p.y)


func _value_noise(value: Vector2) -> float:
	var cell := value.floor()
	var local := Vector2(_fract(value.x), _fract(value.y))
	var smooth_local := local * local * (Vector2(3.0, 3.0) - 2.0 * local)
	var a := _hash21(cell)
	var b := _hash21(cell + Vector2(1.0, 0.0))
	var c := _hash21(cell + Vector2(0.0, 1.0))
	var d := _hash21(cell + Vector2(1.0, 1.0))
	return lerpf(lerpf(a, b, smooth_local.x), lerpf(c, d, smooth_local.x),
			smooth_local.y)


func _layered_noise(value: Vector2) -> float:
	var low := _value_noise(value)
	var middle := _value_noise(value * 2.03 + Vector2(11.7, 4.3))
	var fine := _value_noise(value * 4.09 + Vector2(3.1, 17.8))
	return low * 0.58 + middle * 0.28 + fine * 0.14


func _fract(value: float) -> float:
	return value - floor(value)
