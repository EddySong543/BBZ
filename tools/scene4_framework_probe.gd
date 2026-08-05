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
	await _shot(ProbeOutput.path("scene4_framework_center.png"))
	await get_tree().create_timer(2.4).timeout
	await _shot(ProbeOutput.path("scene4_ambient_fx_later.png"))
	await get_tree().create_timer(2.4).timeout
	await _shot(ProbeOutput.path("scene4_ambient_fx_alternate.png"))
	await _capture_layer_motion(screen, stage)

	# Re-baseline immediately before the parallax assertion. The layered motion
	# capture intentionally hides most CanvasItems for several seconds.
	stage.set("_pnx", 0.0)
	stage.call("_process", 0.0)
	screen.call("_process", 0.0)
	var platform_center_x := platform.position.x
	var world_center_x := world.position.x
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


func _capture_layer_motion(screen: Control, stage: BattleStage) -> void:
	# Stop countdown/tween callbacks from re-showing HUD nodes during the long
	# isolated captures. Shader TIME continues independently.
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	for child: Node in screen.get_children():
		if child is CanvasItem and child != screen.get_node("StageSlot"):
			(child as CanvasItem).visible = false

	var atmosphere_layers: Array[String] = [
		"PreviewBackdrop",
		"Sky",
		"FarForest",
		"RuinStone1",
		"RuinStone2",
		"RuinStone3",
		"RuinStone4",
		"BackgroundTree2",
		"BackgroundTree",
		"BackgroundTopLeaves",
		"CanopyLightShafts",
		"MidgroundMist",
		"CanopyMotes",
		"RuinMotes1",
		"RuinMotes2",
		"RuinMotes3",
		"RuinMotes4",
		"BattlePlatform",
		"ForegroundFog",
	]
	for child: Node in stage.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = child.name in atmosphere_layers
	await _shot(ProbeOutput.path("scene4_midground_atmosphere_a.png"))
	await get_tree().create_timer(3.6).timeout
	await _shot(ProbeOutput.path("scene4_midground_atmosphere_b.png"))

	var foreground_fog_layers: Array[String] = [
		"PreviewBackdrop",
		"BattlePlatform",
		"LeftTree",
		"RightTree",
		"TopLeaves",
		"ForegroundFog",
	]
	for child: Node in stage.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = child.name in foreground_fog_layers
	await _shot(ProbeOutput.path("scene4_foreground_fog_a.png"))
	await get_tree().create_timer(3.2).timeout
	await _shot(ProbeOutput.path("scene4_foreground_fog_b.png"))

	var stone_layers: Array[String] = [
		"PreviewBackdrop",
		"Sky",
		"FarForest",
		"RuinStone1",
		"RuinStone2",
		"RuinStone3",
		"RuinStone4",
	]
	for child: Node in stage.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = child.name in stone_layers
	await _shot(ProbeOutput.path("scene4_stone_flow_a.png"))
	await get_tree().create_timer(0.75).timeout
	await _shot(ProbeOutput.path("scene4_stone_flow_smooth_b.png"))
	await get_tree().create_timer(0.75).timeout
	await _shot(ProbeOutput.path("scene4_stone_flow_smooth_c.png"))
	await get_tree().create_timer(5.5).timeout
	await _shot(ProbeOutput.path("scene4_stone_flow_b.png"))

	var sway_layers: Array[String] = [
		"PreviewBackdrop",
		"BackgroundTopLeaves",
		"LeftTree",
		"RightTree",
		"TopLeaves",
	]
	for child: Node in stage.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = child.name in sway_layers
	await _shot(ProbeOutput.path("scene4_hanging_sway_a.png"))
	await get_tree().create_timer(2.2).timeout
	await _shot(ProbeOutput.path("scene4_hanging_sway_b.png"))


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	if not is_instance_valid(self):
		return
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Scene4 framework probe could not save %s (error=%d)" % [path, error])
