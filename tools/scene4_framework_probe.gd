extends Node

const ProbeOutput := preload("res://tools/probe_output.gd")


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(0, 0)
	BattleSetup.reset()
	var packed := load("res://src/ui/battle_screen4.tscn") as PackedScene
	var screen := packed.instantiate()
	add_child(screen)
	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(screen):
		get_tree().quit(1)
		return

	var stage := screen.get_node("StageSlot/Stage") as BattleStage
	var platform := stage.get_node("BattlePlatform") as Control
	var world := screen.get_node("WorldGroup") as Control
	stage.set_process(false)
	screen.set_process(false)

	stage.set("_pnx", 0.0)
	stage.call("_process", 0.0)
	screen.call("_process", 0.0)
	var platform_center_x := platform.position.x
	var world_center_x := world.position.x
	await _shot(ProbeOutput.path("scene4_framework_center.png"))

	stage.set("_pnx", 1.0)
	stage.call("_process", 0.0)
	screen.call("_process", 0.0)
	var platform_delta := platform.position.x - platform_center_x
	var world_delta := world.position.x - world_center_x
	var sync_error := absf(platform_delta - world_delta)
	await _shot(ProbeOutput.path("scene4_framework_right.png"))
	print(
			"SCENE4_FRAMEWORK_PROBE: PASS platform_delta=",
			platform_delta,
			" world_delta=",
			world_delta,
			" error=",
			sync_error)
	BattleSetup.reset()
	get_tree().quit(0 if is_zero_approx(sync_error) else 1)


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	if not is_instance_valid(self):
		return
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Scene4 framework probe could not save %s (error=%d)" % [path, error])
