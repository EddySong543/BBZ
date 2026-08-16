extends Node

const ProbeOutput := preload("res://tools/probe_output.gd")


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(0, 0)
	BattleSetup.reset()
	var packed := load("res://src/ui/battle_screen5.tscn") as PackedScene
	var screen := packed.instantiate() as Control
	add_child(screen)
	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(screen):
		get_tree().quit(1)
		return

	var stage := screen.get_node("StageSlot/Stage") as BattleStage
	var platform := stage.get_node("BattlePlatform") as Control
	var world := screen.get_node("WorldGroup") as Control
	var near_wheat := stage.get_node("NearWheatLeft") as Control
	var occluder := world.get_node("WorldForegroundOccluder") as TextureRect
	stage.set_process(false)
	screen.set_process(false)

	stage.set("_pnx", 0.0)
	stage.call("_process", 0.0)
	screen.call("_process", 0.0)
	await _shot(ProbeOutput.path("scene5_framework_center.png"))

	var platform_center_x: float = platform.position.x
	var world_center_x: float = world.position.x
	var center_occluder_error: float = occluder.global_position.distance_to(
			near_wheat.global_position)
	stage.set("_pnx", 1.0)
	stage.call("_process", 0.0)
	screen.call("_process", 0.0)
	var platform_delta: float = platform.position.x - platform_center_x
	var world_delta: float = world.position.x - world_center_x
	var sync_error: float = absf(platform_delta - world_delta)
	var right_occluder_error: float = occluder.global_position.distance_to(
			near_wheat.global_position)
	await _shot(ProbeOutput.path("scene5_framework_right.png"))

	var required_nodes: Array[String] = [
		"P1Hud",
		"P2Hud",
		"Buttons",
		"WorldGroup/P1CharDisplay",
		"WorldGroup/P2CharDisplay",
		"WorldGroup/WorldForegroundOccluder",
	]
	var missing_nodes: Array[String] = []
	for node_path: String in required_nodes:
		if screen.get_node_or_null(node_path) == null:
			missing_nodes.append(node_path)

	var occluder_is_foreground := (
			occluder.get_index()
			> world.get_node("P2CharDisplay").get_index())
	var passed := (
			is_zero_approx(sync_error)
			and center_occluder_error < 0.01
			and right_occluder_error < 0.01
			and occluder_is_foreground
			and missing_nodes.is_empty())
	print(
			"SCENE5_FRAMEWORK_PROBE: ",
			"PASS" if passed else "FAIL",
			" platform_delta=",
			platform_delta,
			" world_delta=",
			world_delta,
			" error=",
			sync_error,
			" occluder_center_error=",
			center_occluder_error,
			" occluder_right_error=",
			right_occluder_error,
			" occluder_is_foreground=",
			occluder_is_foreground,
			" missing=",
			missing_nodes)
	BattleSetup.reset()
	get_tree().quit(0 if passed else 1)


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	if not is_instance_valid(self):
		return
	var error: Error = get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error(
				"Scene5 framework probe could not save %s (error=%d)"
				% [path, error])
