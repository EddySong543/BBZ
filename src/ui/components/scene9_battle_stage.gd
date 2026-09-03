extends BattleStage

## Scene9 treats the assembled battle platform as screen-fixed ground.
## The shared battle screen asks the stage for the fighter/shadow pointer offset,
## so returning zero here keeps WorldGroup on the same plane as Scene9's
## pointer-disabled platform pieces without changing any other scene.

const EASTER_EGG_TRIGGER_PROBABILITY := 0.12

var _interactive_clouds: Array[TextureRect] = []
var _interaction_controller: Node = null
var _eye_socket_bird_flock: Control = null
var _easter_egg_rng := RandomNumberGenerator.new()
var _easter_egg_roll_override := -1.0
var _easter_egg_roll_count := 0
var _easter_egg_trigger_count := 0


func _ready() -> void:
	super()
	# Front-to-back order: overlapping pixels must trigger only the visible bank.
	for cloud_name: String in ["DistantPixelCloudBank", "DistantPixelCloudBank2"]:
		var cloud := get_node_or_null(cloud_name) as TextureRect
		if cloud != null:
			_interactive_clouds.append(cloud)
	_interaction_controller = get_node_or_null("SceneInteractionController")
	_eye_socket_bird_flock = get_node_or_null(
			"DistantLeftMountain/EyeSocketBirdFlock") as Control
	_easter_egg_rng.randomize()


func pointer_ground_offset() -> Vector2:
	return Vector2.ZERO


func register_scene_click_at_canvas_position(canvas_position: Vector2) -> bool:
	var interaction_registered := false
	if _interaction_controller != null:
		if bool(_interaction_controller.call(
				"trigger_grass_at_canvas_position", canvas_position)):
			interaction_registered = true
	if not interaction_registered:
		interaction_registered = register_cloud_click_at_canvas_position(
				canvas_position)
	if interaction_registered:
		_try_trigger_eye_socket_bird_flock()
	return interaction_registered


func register_cloud_click_at_canvas_position(canvas_position: Vector2) -> bool:
	if _interactive_clouds.is_empty():
		return false
	var clicked_cloud: TextureRect = null
	for cloud: TextureRect in _interactive_clouds:
		if bool(cloud.call(
				"try_spawn_ripple_at_canvas_position", canvas_position)):
			clicked_cloud = cloud
			break
	if clicked_cloud == null:
		return false

	return true


func interactive_cloud_count_for_testing() -> int:
	return _interactive_clouds.size()


func set_easter_egg_roll_for_testing(value: float) -> void:
	_easter_egg_roll_override = clampf(value, 0.0, 1.0)


func easter_egg_contract_snapshot() -> Dictionary:
	return {
		"effect": "eye_socket_bird_flock",
		"trigger_probability": EASTER_EGG_TRIGGER_PROBABILITY,
		"trigger_source": "validated_grass_or_cloud_click",
		"roll_count": _easter_egg_roll_count,
		"trigger_count": _easter_egg_trigger_count,
		"repeatable_after_completion": true,
		"rolls_while_active": false,
		"invalid_clicks_roll": false,
	}


func _try_trigger_eye_socket_bird_flock() -> void:
	if (_eye_socket_bird_flock == null
			or bool(_eye_socket_bird_flock.call("is_active"))):
		return
	_easter_egg_roll_count += 1
	var sample := (_easter_egg_roll_override
			if _easter_egg_roll_override >= 0.0
			else _easter_egg_rng.randf())
	if sample >= EASTER_EGG_TRIGGER_PROBABILITY:
		return
	if bool(_eye_socket_bird_flock.call("start_flock")):
		_easter_egg_trigger_count += 1
