class_name BootCharacterIdle
extends Control

const NATIVE_SIZE := Vector2(1677.9402, 1014.42)
const NATIVE_RIG_POSITION := Vector2(0.0, 57.48)
const NATIVE_RIG_SCALE := Vector2(5.26, 5.26)
const CHARACTER_TEXTURE_SIZE := Vector2(319.0, 171.0)
const REAR_HAND_ANCHOR_HOME := Vector2(112.68, 47.125)
const PERSPECTIVE_PIVOT := Vector2(0.56, 0.50)
const FRONT_HAND_START := 0.62
const FRONT_HAND_DEPTH_BOOST := 1.25

@export_range(1.0, 8.0, 0.1) var loop_duration: float = 6.4
@export_range(4.0, 12.0, 0.1) var waist_loop_duration: float = 9.0
@export_range(2.0, 10.0, 0.1) var energy_pulse_loop_duration: float = 6.0
@export_range(0.0, 0.3, 0.01) var pointer_dead_zone: float = 0.08
@export_range(1.0, 12.0, 0.1) var pointer_energy_smooth: float = 5.0
@export_range(0.0, 6.0, 0.1) var pointer_character_yaw_degrees: float = 3.0
@export_range(0.0, 3.0, 0.1) var pointer_character_pitch_degrees: float = 1.2
@export_range(1.0, 12.0, 0.1) var pointer_character_smooth: float = 4.2

@onready var _rig: Node2D = $Rig
@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _waist_animation_player: AnimationPlayer = $WaistAnimationPlayer
@onready var _rear_hand_glow: ColorRect = (
		$Rig/RearHandEnergyAnchor/RearHandGlow)
@onready var _rear_hand_star: ColorRect = (
		$Rig/RearHandEnergyAnchor/RearHandStar)
@onready var _rear_hand_energy_anchor: Marker2D = (
		$Rig/RearHandEnergyAnchor)
@onready var _base_material: ShaderMaterial = (
		$Rig/Base.material as ShaderMaterial)
@onready var _intro_overlay_sprites: Array[Sprite2D] = [
	$Rig/Base/Shadow,
	$Rig/WaistScreenRightPivot/WaistScreenRight,
	$Rig/WaistScreenLeftPivot/WaistScreenLeft,
	$Rig/FurRightTips,
	$Rig/HairLeftTips,
	$Rig/HairRightTips,
	$Rig/HairFrontTips,
]

const IDLE_GLOW_INTENSITY := 0.78
const IDLE_STAR_INTENSITY := 1.0

var _intro_active: bool = false
var _energy_pulse_elapsed: float = 0.0
var _pointer_energy_response: Vector2 = Vector2.ZERO
var _pointer_character_response: Vector2 = Vector2.ZERO
var _pointer_preview_active: bool = false


func _ready() -> void:
	resized.connect(_sync_rig_to_size)
	_sync_rig_to_size()
	_install_idle_animation()
	_install_waist_animation()
	_animation_player.play(&"idle")
	_waist_animation_player.play(&"waist_idle")
	_sync_energy_pulse()


func _sync_rig_to_size() -> void:
	if _rig == null:
		return
	var size_ratio := Vector2(
		size.x / NATIVE_SIZE.x,
		size.y / NATIVE_SIZE.y)
	_rig.position = NATIVE_RIG_POSITION * size_ratio
	_rig.scale = NATIVE_RIG_SCALE * size_ratio


func _process(delta: float) -> void:
	if not _intro_active:
		_energy_pulse_elapsed = fposmod(
			_energy_pulse_elapsed + delta,
			maxf(energy_pulse_loop_duration, 0.001))
	_sync_energy_pulse()
	_update_pointer_response(delta)


func prepare_intro() -> void:
	_intro_active = true
	_energy_pulse_elapsed = 0.0
	_pointer_energy_response = Vector2.ZERO
	_pointer_character_response = Vector2.ZERO
	_apply_pointer_response()
	_animation_player.stop()
	_animation_player.seek(0.0, true)
	_waist_animation_player.stop()
	_waist_animation_player.seek(0.0, true)
	set_intro_state(0.0, 0.0, 0.0)


func set_intro_state(
	light_progress: float,
	star_intensity: float,
	glow_intensity: float,
	star_pulse_progress: float = -1.0,
	impact_progress: float = 0.0,
) -> void:
	var safe_light := clampf(light_progress, 0.0, 1.0)
	if _base_material != null:
		_base_material.set_shader_parameter(
			&"intro_light_progress",
			safe_light)
		_base_material.set_shader_parameter(
			&"intro_impact_progress",
			clampf(impact_progress, 0.0, 1.0))
	_set_energy_intensity(_rear_hand_star, star_intensity)
	_set_energy_intensity(_rear_hand_glow, glow_intensity)
	var star_material := _rear_hand_star.material as ShaderMaterial
	if star_material != null:
		star_material.set_shader_parameter(
			&"exit_release_enabled",
			0.0)
		star_material.set_shader_parameter(
			&"exit_release_progress",
			0.0)
		star_material.set_shader_parameter(
			&"intro_pulse_enabled",
			1.0 if star_pulse_progress >= 0.0 else 0.0)
		star_material.set_shader_parameter(
			&"intro_pulse_progress",
			clampf(star_pulse_progress, 0.0, 1.0))

	var overlay_light := smoothstep(
		0.08,
		0.96,
		safe_light)
	var impact_envelope := maxf(
		sin(clampf(impact_progress, 0.0, 1.0) * PI),
		0.0)
	for overlay_sprite: Sprite2D in _intro_overlay_sprites:
		overlay_sprite.modulate = Color(
			overlay_light,
			overlay_light * lerpf(1.0, 0.98, impact_envelope),
			overlay_light * lerpf(1.0, 0.91, impact_envelope),
			1.0)


func set_exit_release_progress(progress: float) -> void:
	var safe_progress := clampf(progress, 0.0, 1.0)
	var release_progress := smoothstep(0.0, 1.0, safe_progress)
	var star_material := _rear_hand_star.material as ShaderMaterial
	if star_material != null:
		star_material.set_shader_parameter(&"intro_pulse_enabled", 0.0)
		star_material.set_shader_parameter(&"intro_pulse_progress", 0.0)
		star_material.set_shader_parameter(&"exit_release_enabled", 1.0)
		star_material.set_shader_parameter(
			&"exit_release_progress",
			safe_progress)
	_set_energy_intensity(
		_rear_hand_star,
		lerpf(IDLE_STAR_INTENSITY, 2.35, release_progress))
	_set_energy_intensity(
		_rear_hand_glow,
		lerpf(IDLE_GLOW_INTENSITY, 1.38, release_progress))


func finish_intro() -> void:
	set_intro_state(
		1.0,
		IDLE_STAR_INTENSITY,
		IDLE_GLOW_INTENSITY,
		-1.0,
		1.0)
	for overlay_sprite: Sprite2D in _intro_overlay_sprites:
		overlay_sprite.modulate = Color.WHITE
	_intro_active = false
	_energy_pulse_elapsed = 0.0
	_animation_player.play(&"idle")
	_animation_player.seek(0.0, true)
	_waist_animation_player.play(&"waist_idle")
	_waist_animation_player.seek(0.0, true)
	_sync_energy_pulse()


func _sync_energy_pulse() -> void:
	var pulse_phase := (
			fposmod(
				_energy_pulse_elapsed,
				maxf(energy_pulse_loop_duration, 0.001))
			/ maxf(energy_pulse_loop_duration, 0.001))
	for energy_node: ColorRect in [_rear_hand_glow, _rear_hand_star]:
		var shader_material := energy_node.material as ShaderMaterial
		if shader_material != null:
			shader_material.set_shader_parameter(&"pulse_phase", pulse_phase)
	if _base_material != null:
		_base_material.set_shader_parameter(&"energy_phase", pulse_phase)


func energy_pulse_interval_seconds() -> float:
	return maxf(energy_pulse_loop_duration, 0.001) * 0.5


func _update_pointer_response(delta: float) -> void:
	if _pointer_preview_active:
		return
	var target := Vector2.ZERO
	if not _intro_active:
		target = _pointer_target_from_viewport()
	var energy_response := (
		1.0 - exp(-maxf(pointer_energy_smooth, 0.001) * delta))
	var character_response := (
		1.0 - exp(-maxf(pointer_character_smooth, 0.001) * delta))
	_pointer_energy_response = _pointer_energy_response.lerp(
		target,
		energy_response)
	_pointer_character_response = _pointer_character_response.lerp(
		target,
		character_response)
	_apply_pointer_response()


func _pointer_target_from_viewport() -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2.ZERO
	var mouse_position := get_viewport().get_mouse_position()
	if not Rect2(Vector2.ZERO, viewport_size).has_point(mouse_position):
		return Vector2.ZERO
	var normalized := Vector2(
		(mouse_position.x / viewport_size.x - 0.5) * 2.0,
		(mouse_position.y / viewport_size.y - 0.5) * 2.0)
	return _apply_pointer_dead_zone(normalized)


func _apply_pointer_dead_zone(normalized_pointer: Vector2) -> Vector2:
	var clamped := Vector2(
		clampf(normalized_pointer.x, -1.0, 1.0),
		clampf(normalized_pointer.y, -1.0, 1.0))
	var magnitude := clamped.length()
	if magnitude <= pointer_dead_zone:
		return Vector2.ZERO
	var remapped_magnitude := clampf(
		(magnitude - pointer_dead_zone)
		/ maxf(1.0 - pointer_dead_zone, 0.001),
		0.0,
		1.0)
	return clamped.normalized() * remapped_magnitude


func _apply_pointer_response() -> void:
	for energy_node: ColorRect in [
		_rear_hand_star,
		_rear_hand_glow,
	]:
		var shader_material := energy_node.material as ShaderMaterial
		if shader_material != null:
			shader_material.set_shader_parameter(
				&"pointer_tilt",
				_pointer_energy_response)

	var yaw_strength := tan(deg_to_rad(pointer_character_yaw_degrees))
	var pitch_strength := tan(deg_to_rad(pointer_character_pitch_degrees))
	for perspective_material: ShaderMaterial in (
			_character_perspective_materials()):
		perspective_material.set_shader_parameter(
			&"pointer_tilt",
			_pointer_character_response)
		perspective_material.set_shader_parameter(
			&"pointer_yaw_strength",
			yaw_strength)
		perspective_material.set_shader_parameter(
			&"pointer_pitch_strength",
			pitch_strength)
	_update_rear_hand_energy_anchor(yaw_strength, pitch_strength)


func preview_pointer_response(normalized_pointer: Vector2) -> void:
	_pointer_preview_active = true
	var target := _apply_pointer_dead_zone(normalized_pointer)
	_pointer_energy_response = target
	_pointer_character_response = target
	_apply_pointer_response()


func current_pointer_response() -> Vector2:
	return _pointer_energy_response


func current_character_pointer_response() -> Vector2:
	return _pointer_character_response


func finish_pointer_preview() -> void:
	_pointer_preview_active = false


func _character_perspective_materials() -> Array[ShaderMaterial]:
	var materials: Array[ShaderMaterial] = []
	if _base_material != null:
		materials.append(_base_material)
	for sprite: Sprite2D in _intro_overlay_sprites:
		var material := sprite.material as ShaderMaterial
		if material != null:
			materials.append(material)
	return materials


func _update_rear_hand_energy_anchor(
		yaw_strength: float,
		pitch_strength: float,
) -> void:
	if _rear_hand_energy_anchor == null:
		return
	_rear_hand_energy_anchor.position = _perspective_display_position(
			REAR_HAND_ANCHOR_HOME, yaw_strength, pitch_strength)


func _perspective_display_position(
		source_position: Vector2,
		yaw_strength: float,
		pitch_strength: float,
) -> Vector2:
	var source_uv := source_position / CHARACTER_TEXTURE_SIZE
	var display_uv := source_uv
	for iteration: int in 4:
		var local_uv := display_uv - PERSPECTIVE_PIVOT
		var front_mask := smoothstep(
			FRONT_HAND_START,
			0.98,
			display_uv.x)
		var depth_axis := local_uv.x * lerpf(
			1.0,
			FRONT_HAND_DEPTH_BOOST,
			front_mask)
		var pointer_scale := maxf(
			1.0
				+ depth_axis
					* _pointer_character_response.x
					* yaw_strength
				+ local_uv.y
					* _pointer_character_response.y
					* pitch_strength,
			0.88)
		display_uv = (
			PERSPECTIVE_PIVOT
			+ (source_uv - PERSPECTIVE_PIVOT) * pointer_scale)
	return display_uv * CHARACTER_TEXTURE_SIZE


func preview_idle_at_time(seconds: float) -> void:
	var safe_seconds := maxf(seconds, 0.0)
	_energy_pulse_elapsed = fposmod(
		safe_seconds,
		maxf(energy_pulse_loop_duration, 0.001))
	if _animation_player.has_animation(&"idle"):
		_animation_player.pause()
		_animation_player.seek(
			fposmod(safe_seconds, maxf(loop_duration, 0.001)),
			true)
	if _waist_animation_player.has_animation(&"waist_idle"):
		_waist_animation_player.pause()
		_waist_animation_player.seek(
			fposmod(
				safe_seconds,
				maxf(waist_loop_duration, 0.001)),
			true)
	_sync_energy_pulse()


func _set_energy_intensity(
		energy_node: ColorRect,
		intensity: float,
) -> void:
	var shader_material := energy_node.material as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter(
			&"intensity",
			maxf(intensity, 0.0))


func _install_idle_animation() -> void:
	var library := AnimationLibrary.new()
	var animation := Animation.new()
	animation.length = loop_duration
	animation.loop_mode = Animation.LOOP_LINEAR

	var times := PackedFloat32Array([
		0.0,
		loop_duration * 0.125,
		loop_duration * 0.25,
		loop_duration * 0.375,
		loop_duration * 0.5,
		loop_duration * 0.625,
		loop_duration * 0.75,
		loop_duration * 0.875,
		loop_duration,
	])

	_add_pixel_track(
		animation,
		NodePath("Rig/HairLeftTips:position"),
		times,
		[
			Vector2.ZERO,
			Vector2(0.06, 0),
			Vector2(0.18, 0),
			Vector2(0.30, 0),
			Vector2(0.24, 0),
			Vector2(0.05, 0),
			Vector2(-0.14, 0),
			Vector2(-0.08, 0),
			Vector2.ZERO,
		])
	_add_pixel_track(
		animation,
		NodePath("Rig/HairRightTips:position"),
		times,
		[
			Vector2(-0.05, 0),
			Vector2.ZERO,
			Vector2(0.12, 0),
			Vector2(0.27, 0),
			Vector2(0.30, 0),
			Vector2(0.15, 0),
			Vector2(-0.08, 0),
			Vector2(-0.12, 0),
			Vector2(-0.05, 0),
		])
	_add_pixel_track(
		animation,
		NodePath("Rig/HairFrontTips:position"),
		times,
		[
			Vector2.ZERO,
			Vector2.ZERO,
			Vector2(0.03, 0),
			Vector2(0.08, 0),
			Vector2(0.14, 0),
			Vector2(0.10, 0),
			Vector2.ZERO,
			Vector2(-0.04, 0),
			Vector2.ZERO,
		])
	_add_pixel_track(
		animation,
		NodePath("Rig/FurRightTips:position"),
		times,
		[
			Vector2.ZERO,
			Vector2.ZERO,
			Vector2(0.04, -0.01),
			Vector2(0.10, -0.03),
			Vector2(0.14, -0.04),
			Vector2(0.09, -0.02),
			Vector2.ZERO,
			Vector2(-0.04, 0.01),
			Vector2.ZERO,
		])
	library.add_animation(&"idle", animation)
	_animation_player.add_animation_library(&"", library)


func _install_waist_animation() -> void:
	var library := AnimationLibrary.new()
	var animation := Animation.new()
	var waist_duration := waist_loop_duration
	animation.length = waist_duration
	animation.loop_mode = Animation.LOOP_LINEAR

	var times := PackedFloat32Array([
		0.0,
		waist_duration * 0.125,
		waist_duration * 0.25,
		waist_duration * 0.375,
		waist_duration * 0.5,
		waist_duration * 0.625,
		waist_duration * 0.75,
		waist_duration * 0.875,
		waist_duration,
	])
	_add_waist_rotation_track(
		animation,
		NodePath("Rig/WaistScreenRightPivot:rotation"),
		times,
		[
			0.0,
			-0.0212,
			-0.030,
			-0.0212,
			0.0,
			0.0212,
			0.030,
			0.0212,
			0.0,
		])
	_add_waist_rotation_track(
		animation,
		NodePath("Rig/WaistScreenLeftPivot:rotation"),
		times,
		[
			0.0156,
			0.0,
			-0.0156,
			-0.022,
			-0.0156,
			0.0,
			0.0156,
			0.022,
			0.0156,
		])

	library.add_animation(&"waist_idle", animation)
	_waist_animation_player.add_animation_library(&"", library)


func _add_pixel_track(
		animation: Animation,
		path: NodePath,
		times: PackedFloat32Array,
		values: Array[Vector2]) -> void:
	assert(times.size() == values.size())
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, path)
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	animation.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
	for index: int in times.size():
		animation.track_insert_key(track, times[index], values[index])


func _add_waist_rotation_track(
		animation: Animation,
		path: NodePath,
		times: PackedFloat32Array,
		values: Array[float]) -> void:
	assert(times.size() == values.size())
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, path)
	animation.track_set_interpolation_type(
			track, Animation.INTERPOLATION_CUBIC_ANGLE)
	animation.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
	for index: int in times.size():
		animation.track_insert_key(track, times[index], values[index])
