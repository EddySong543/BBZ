extends Control

const NATIVE_SIZE := Vector2(1677.9402, 1014.42)
const NATIVE_RIG_POSITION := Vector2(0.0, 57.48)
const NATIVE_RIG_SCALE := Vector2(5.26, 5.26)

@export_range(1.0, 8.0, 0.1) var loop_duration: float = 4.8

@onready var _rig: Node2D = $Rig
@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _waist_animation_player: AnimationPlayer = $WaistAnimationPlayer
@onready var _rear_hand_glow: ColorRect = (
		$Rig/RearHandEnergyAnchor/RearHandGlow)
@onready var _rear_hand_star: ColorRect = (
		$Rig/RearHandEnergyAnchor/RearHandStar)
@onready var _base_material: ShaderMaterial = (
		$Rig/Base.material as ShaderMaterial)


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


func _process(_delta: float) -> void:
	_sync_energy_pulse()


func _sync_energy_pulse() -> void:
	var pulse_phase := (
			fposmod(_animation_player.current_animation_position, loop_duration)
			/ loop_duration)
	for energy_node: ColorRect in [_rear_hand_glow, _rear_hand_star]:
		var shader_material := energy_node.material as ShaderMaterial
		if shader_material != null:
			shader_material.set_shader_parameter(&"pulse_phase", pulse_phase)
	if _base_material != null:
		_base_material.set_shader_parameter(&"energy_phase", pulse_phase)


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
			Vector2(0.10, 0),
			Vector2(0.28, 0),
			Vector2(0.38, 0),
			Vector2(0.25, 0),
			Vector2.ZERO,
			Vector2(-0.18, 0),
			Vector2(-0.10, 0),
			Vector2.ZERO,
		])
	_add_pixel_track(
		animation,
		NodePath("Rig/HairRightTips:position"),
		times,
		[
			Vector2.ZERO,
			Vector2.ZERO,
			Vector2(0.19, 0),
			Vector2(0.38, 0),
			Vector2(0.28, 0),
			Vector2(0.08, 0),
			Vector2(-0.15, 0),
			Vector2(-0.08, 0),
			Vector2.ZERO,
		])
	_add_pixel_track(
		animation,
		NodePath("Rig/HairFrontTips:position"),
		times,
		[
			Vector2.ZERO,
			Vector2.ZERO,
			Vector2.ZERO,
			Vector2(0.09, 0),
			Vector2(0.19, 0),
			Vector2(0.09, 0),
			Vector2.ZERO,
			Vector2.ZERO,
			Vector2.ZERO,
		])
	library.add_animation(&"idle", animation)
	_animation_player.add_animation_library(&"", library)


func _install_waist_animation() -> void:
	var library := AnimationLibrary.new()
	var animation := Animation.new()
	var waist_duration := 8.0
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
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
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
