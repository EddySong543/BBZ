@tool
class_name MainHubCharacter
extends Control

## Main-hub controllable character. The root remains an editor-friendly ground
## anchor; display scale, facing and the optional expedition gait live on Visual.

enum MovementStyle {
	CONTINUOUS,
	EXPEDITION_GAIT,
}

const TOKEN_SIZE := Vector2(208.0, 208.0)
const TOKEN_FOOT_ANCHOR := Vector2(104.0, 156.0)
const TOKEN_CONTENT_SCALE: float = 1.125
const DISPLAY_SCALE: float = 1.5
const H01_SOURCE_FOOT_MIDPOINT := Vector2(128.0, 182.0)
const TOKEN_IDLE_BASE_FPS: float = 8.0
const TOKEN_IDLE_REF_FRAMES: float = 6.0
const WALK_SOURCE_FOOT_MIDPOINT := Vector2(64.0, 91.0)
const WALK_CONTENT_SCALE: float = TOKEN_CONTENT_SCALE * 2.0
const WALK_FPS: float = 8.0
const DEFAULT_IDLE_FRAMES_PATH := "res://assets/sprites/heroes/h01/h01_idle.tres"
const DEFAULT_WALK_FRAMES_PATH := "res://assets/sprites/heroes/h01/h01_walk.tres"

const GAIT_STRIDE_DISTANCE: float = 96.0
const GAIT_STEP_PIXELS: float = 5.0
const GAIT_LEAD_STEPS: float = 2.0
const GAIT_HOP_STEPS: float = 2.0
const GAIT_WOBBLE: float = 0.026
const GAIT_TURN_SQUEEZE: float = 0.82
const GAIT_TURN_LIFT: float = 1.05

@export_file("*.tres") var sprite_frames_path: String = DEFAULT_IDLE_FRAMES_PATH
@export_file("*.tres") var walk_frames_path: String = DEFAULT_WALK_FRAMES_PATH
@export_enum("Continuous", "Expedition Gait") var movement_style: int = \
		MovementStyle.EXPEDITION_GAIT
@export_range(1.0, 1000.0, 1.0) var move_speed: float = 320.0
@export var minimum_foot_x: float = 120.0
@export var maximum_foot_x: float = 1800.0

@onready var _visual: TextureRect = $Visual
@onready var _shadow: MainHubCharacterShadow = $PlayerShadow

var _idle_frames: SpriteFrames
var _idle_textures: Array[Texture2D] = []
var _walk_frames: SpriteFrames
var _walk_textures: Array[Texture2D] = []
var _animation_time: float = 0.0
var _foot_x: float = 0.0
var _fixed_foot_y: float = 0.0
var _facing_sign: float = 1.0
var _is_walking: bool = false
var _gait_distance: float = 0.0
var _gait_direction: float = 1.0
var _turn_amount: float = 0.0


func _ready() -> void:
	size = TOKEN_SIZE
	pivot_offset = TOKEN_FOOT_ANCHOR
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = null
	modulate = Color.WHITE
	self_modulate = Color.WHITE
	_foot_x = clampf(position.x + TOKEN_FOOT_ANCHOR.x,
			minimum_foot_x, maximum_foot_x)
	_fixed_foot_y = position.y + TOKEN_FOOT_ANCHOR.y
	_snap_to_fixed_ground()
	_reset_visual_pose()
	_reload_animation_resources()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var horizontal_axis := Input.get_axis(&"ui_left", &"ui_right")
	if Input.is_key_pressed(KEY_A):
		horizontal_axis -= 1.0
	if Input.is_key_pressed(KEY_D):
		horizontal_axis += 1.0
	move_horizontal(clampf(horizontal_axis, -1.0, 1.0), delta)
	_animation_time += maxf(delta, 0.0)
	_update_current_frame()


func load_sprite_frames(path: String) -> void:
	var matching_walk_path := DEFAULT_WALK_FRAMES_PATH \
			if path == DEFAULT_IDLE_FRAMES_PATH else ""
	configure_animation_resources(path, matching_walk_path)


func configure_animation_resources(idle_path: String, walk_path: String) -> void:
	sprite_frames_path = idle_path
	walk_frames_path = walk_path
	_reload_animation_resources()


func _reload_animation_resources() -> void:
	_idle_frames = null
	_idle_textures.clear()
	_walk_frames = null
	_walk_textures.clear()
	_animation_time = 0.0
	_is_walking = false
	if is_instance_valid(_visual):
		_visual.texture = null
	_idle_frames = _load_frames(sprite_frames_path, &"idle")
	if _idle_frames != null:
		_idle_textures = _build_token_textures(_idle_frames, &"idle",
				TOKEN_CONTENT_SCALE, H01_SOURCE_FOOT_MIDPOINT)
	_walk_frames = _load_frames(walk_frames_path, &"walk")
	if _walk_frames != null:
		_walk_textures = _build_token_textures(_walk_frames, &"walk",
				WALK_CONTENT_SCALE, WALK_SOURCE_FOOT_MIDPOINT)
	_update_current_frame()


func _load_frames(path: String, animation_name: StringName) -> SpriteFrames:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var loaded_frames := load(path) as SpriteFrames
	if loaded_frames == null or not loaded_frames.has_animation(animation_name) \
			or loaded_frames.get_frame_count(animation_name) <= 0:
		return null
	return loaded_frames


func move_horizontal(axis: float, delta: float) -> void:
	var direction := clampf(axis, -1.0, 1.0)
	var safe_delta := maxf(delta, 0.0)
	if movement_style == MovementStyle.CONTINUOUS:
		_move_continuously(direction, safe_delta)
	else:
		_move_with_expedition_gait(direction, safe_delta)
	_snap_to_fixed_ground()
	_update_current_frame()


func _move_continuously(direction: float, delta: float) -> void:
	_set_walking(not is_zero_approx(direction) and not _walk_textures.is_empty())
	if not is_zero_approx(direction):
		_face_direction(direction)
		_foot_x = clampf(_foot_x + direction * move_speed * delta,
				minimum_foot_x, maximum_foot_x)
	_reset_visual_pose()


func _move_with_expedition_gait(direction: float, delta: float) -> void:
	if not is_zero_approx(direction):
		_face_direction(direction)
		_gait_direction = direction
		var old_foot_x := _foot_x
		_foot_x = clampf(_foot_x + direction * move_speed * delta,
				minimum_foot_x, maximum_foot_x)
		_gait_distance += absf(_foot_x - old_foot_x)
		_set_walking(not _walk_textures.is_empty())
		_apply_expedition_pose()
		return

	var phase := fposmod(_gait_distance, GAIT_STRIDE_DISTANCE)
	if phase > 0.001 and _is_walking:
		var settle_distance := minf(move_speed * delta,
				GAIT_STRIDE_DISTANCE - phase)
		_gait_distance += settle_distance
		if settle_distance + 0.001 < GAIT_STRIDE_DISTANCE - phase:
			_apply_expedition_pose()
			return
	_gait_distance = 0.0
	_set_walking(false)
	_reset_visual_pose()


func _face_direction(direction: float) -> void:
	var next_sign := 1.0 if direction > 0.0 else -1.0
	if not is_equal_approx(next_sign, _facing_sign):
		_turn_amount = 1.0
	_facing_sign = next_sign


func _apply_expedition_pose() -> void:
	if not is_instance_valid(_visual):
		return
	var phase := fposmod(_gait_distance, GAIT_STRIDE_DISTANCE) \
			/ GAIT_STRIDE_DISTANCE
	var lift := maxf(sin(phase * PI), 0.0)
	var lead_steps := roundf(lift * GAIT_LEAD_STEPS)
	var hop_steps := roundf(lift * GAIT_HOP_STEPS)
	var step_offset := Vector2(
			_gait_direction * lead_steps * GAIT_STEP_PIXELS,
			-hop_steps * GAIT_STEP_PIXELS)
	_turn_amount = move_toward(_turn_amount, 0.0, 0.05)
	var squeeze := lerpf(1.0, GAIT_TURN_SQUEEZE, _turn_amount)
	var turn_lift := lerpf(1.0, GAIT_TURN_LIFT, _turn_amount)
	_visual.position = step_offset
	_visual.scale = Vector2(
			_facing_sign * DISPLAY_SCALE * squeeze,
			DISPLAY_SCALE * turn_lift)
	_visual.rotation = _gait_direction * sin(phase * TAU) * GAIT_WOBBLE
	if is_instance_valid(_shadow):
		_shadow.set_motion(lift, _gait_direction)


func _reset_visual_pose() -> void:
	if is_instance_valid(_visual):
		_visual.position = Vector2.ZERO
		_visual.scale = Vector2(_facing_sign * DISPLAY_SCALE, DISPLAY_SCALE)
		_visual.rotation = 0.0
	if is_instance_valid(_shadow):
		_shadow.set_motion(0.0, 0.0)


func _set_walking(value: bool) -> void:
	if _is_walking == value:
		return
	_is_walking = value
	_animation_time = 0.0


func foot_position() -> Vector2:
	return Vector2(_foot_x, _fixed_foot_y)


func visual_foot_position() -> Vector2:
	var visual_offset := _visual.position if is_instance_valid(_visual) else Vector2.ZERO
	return foot_position() + visual_offset


func current_texture() -> Texture2D:
	return _visual.texture if is_instance_valid(_visual) else null


func visual_scale() -> Vector2:
	return _visual.scale if is_instance_valid(_visual) else Vector2.ONE


func visual_rotation() -> float:
	return _visual.rotation if is_instance_valid(_visual) else 0.0


func content_scale() -> float:
	return TOKEN_CONTENT_SCALE


func idle_frame_count() -> int:
	return _idle_textures.size()


func walk_frame_count() -> int:
	return _walk_textures.size()


func animation_state() -> StringName:
	return &"walk" if _is_walking else &"idle"


func _snap_to_fixed_ground() -> void:
	position = Vector2(_foot_x - TOKEN_FOOT_ANCHOR.x,
			_fixed_foot_y - TOKEN_FOOT_ANCHOR.y)


func _build_token_textures(frames: SpriteFrames, animation_name: StringName,
		content_scale_value: float, source_foot_midpoint: Vector2) -> Array[Texture2D]:
	var output: Array[Texture2D] = []
	var frame_count: int = frames.get_frame_count(animation_name)
	var target_size := Vector2i(int(TOKEN_SIZE.x), int(TOKEN_SIZE.y))
	var target_origin := Vector2i(Vector2(
			TOKEN_FOOT_ANCHOR - source_foot_midpoint * content_scale_value).round())
	for frame_index: int in frame_count:
		var source_texture: Texture2D = frames.get_frame_texture(animation_name, frame_index)
		if source_texture == null:
			continue
		var source_image: Image = source_texture.get_image()
		if source_image == null:
			continue
		source_image.convert(Image.FORMAT_RGBA8)
		var scaled_size := Vector2i(Vector2(source_image.get_size()) * content_scale_value)
		source_image.resize(scaled_size.x, scaled_size.y, Image.INTERPOLATE_NEAREST)
		var centered_frame := Image.create(
				target_size.x, target_size.y, false, Image.FORMAT_RGBA8)
		centered_frame.blit_rect(
				source_image, Rect2i(Vector2i.ZERO, scaled_size), target_origin)
		output.append(ImageTexture.create_from_image(centered_frame))
	return output


func _update_current_frame() -> void:
	if not is_instance_valid(_visual):
		return
	var active_textures := _walk_textures if _is_walking else _idle_textures
	if active_textures.is_empty():
		return
	var loop_duration := float(active_textures.size()) / WALK_FPS if _is_walking \
			else TOKEN_IDLE_REF_FRAMES / TOKEN_IDLE_BASE_FPS
	var normalized_time := fposmod(_animation_time, loop_duration) / loop_duration
	var frame_index := mini(int(normalized_time * active_textures.size()),
			active_textures.size() - 1)
	_visual.texture = active_textures[frame_index]
